#!/bin/bash
# Start a server on a unix socket, poke it through the cli, benchmark and
# check-rdb, shut it down.
#
# Usage: smoke_test.sh <expected-version> <valkey-server> <valkey-cli> <valkey-benchmark> <valkey-check-rdb>
# The binaries are rlocationpaths.

# --- bazel runfiles bootstrap ---
# Deliberately before `set -e`: the snippet probes several locations and
# relies on the failures falling through the || chain.
# shellcheck disable=SC1090,SC1091
f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo >&2 "ERROR: cannot find $f"; exit 1; }
# --- end runfiles bootstrap ---
set -euo pipefail

EXPECTED_VERSION="$1"
SERVER=$(rlocation "$2")
CLI=$(rlocation "$3")
BENCHMARK=$(rlocation "$4")
CHECK_RDB=$(rlocation "$5")

# Not under TEST_TMPDIR: sockaddr_un caps the socket path at 104 bytes and
# bazel's sandbox paths run well past that.
WORKDIR=$(mktemp -d /tmp/valkeysmoke.XXXXXX)
SOCK="$WORKDIR/valkey.sock"
SERVER_PID=
cleanup() {
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill -9 "$SERVER_PID" 2>/dev/null || true
    fi
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*"
    [ -f "$WORKDIR/server.log" ] && { echo "--- server.log"; cat "$WORKDIR/server.log"; }
    exit 1
}

expect() {
    local what="$1" want="$2" got="$3"
    [ "$got" = "$want" ] || fail "$what: expected '$want', got '$got'"
}

version=$("$SERVER" --version)
echo "$version"
case "$version" in
    *" v=$EXPECTED_VERSION "*) ;;
    *) fail "expected valkey-server v=$EXPECTED_VERSION" ;;
esac

"$SERVER" --port 0 --unixsocket "$SOCK" --dir "$WORKDIR" --save "" \
    --logfile "$WORKDIR/server.log" --daemonize no &
SERVER_PID=$!

cli() { "$CLI" -s "$SOCK" "$@"; }

for _ in $(seq 1 50); do
    [ "$(cli ping 2>/dev/null)" = "PONG" ] && break
    kill -0 "$SERVER_PID" 2>/dev/null || fail "server exited during startup"
    sleep 0.2
done
expect "ping" "PONG" "$(cli ping)"

info_field() { cli info "$1" | tr -d '\r' | sed -n "s/^$2://p"; }
expect "valkey_version" "$EXPECTED_VERSION" "$(info_field server valkey_version)"
case "$(info_field memory mem_allocator)" in
    jemalloc-*) ;;
    *) fail "mem_allocator: expected jemalloc, got '$(info_field memory mem_allocator)'" ;;
esac

expect "set" "OK" "$(cli set greeting hello)"
expect "get" "hello" "$(cli get greeting)"
expect "eval" "42" "$(cli eval "return redis.call('incrby', KEYS[1], ARGV[1])" 1 counter 42)"
expect "activedefrag" "OK" "$(cli config set activedefrag yes)"

"$BENCHMARK" -s "$SOCK" -n 1000 -t set,get -q > "$WORKDIR/benchmark.log" 2>&1 || {
    cat "$WORKDIR/benchmark.log"; fail "valkey-benchmark exited non-zero";
}
grep -q "requests per second" "$WORKDIR/benchmark.log" || {
    cat "$WORKDIR/benchmark.log"; fail "valkey-benchmark reported no results";
}

expect "save" "OK" "$(cli save)"
"$CHECK_RDB" "$WORKDIR/dump.rdb" > "$WORKDIR/check-rdb.log" 2>&1 || {
    cat "$WORKDIR/check-rdb.log"; fail "valkey-check-rdb exited non-zero";
}
grep -q "RDB looks OK" "$WORKDIR/check-rdb.log" || {
    cat "$WORKDIR/check-rdb.log"; fail "valkey-check-rdb didn't accept the dump";
}

cli shutdown nosave > /dev/null 2>&1 || true
wait "$SERVER_PID" || true
SERVER_PID=

echo "PASS"
