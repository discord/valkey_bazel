#!/usr/bin/env python3
"""Regenerate valkey_bazel/patches/<series>.patch from an upstream release tarball.

Every release in a series (e.g. 9.1.x) shares the same build files, so one patch
covers the whole series. Run this against any release of the series.
"""

import argparse
import difflib
import io
import re
import sys
import tarfile
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PATCHES_DIR = REPO_ROOT / "valkey_bazel" / "patches"

RULES_OVERRIDE = """\
foreach (kind EXE SHARED MODULE)
    string(REPLACE "STRIP_DEBUG_SYMBOLS" "" CMAKE_${kind}_LINKER_FLAGS_INIT "${CMAKE_${kind}_LINKER_FLAGS_INIT}")
endforeach ()
"""

JEMALLOC_CMAKE = """\
project(jemalloc)

set(_jemalloc_find_opts NO_CMAKE_ENVIRONMENT_PATH NO_SYSTEM_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH REQUIRED)
find_path(JEMALLOC_INCLUDE_DIR jemalloc/jemalloc.h ${_jemalloc_find_opts})
find_library(
    JEMALLOC_LIBRARY
    NAMES libjemalloc_core.a libjemalloc_core.pic.a libjemalloc.a libjemalloc.pic.a
    ${_jemalloc_find_opts})
message(STATUS "Using jemalloc: ${JEMALLOC_LIBRARY} (headers: ${JEMALLOC_INCLUDE_DIR})")

add_library(jemalloc STATIC IMPORTED GLOBAL)
set_target_properties(jemalloc PROPERTIES IMPORTED_LOCATION "${JEMALLOC_LIBRARY}")
"""

RELEASE_H = """\
#define REDIS_GIT_SHA1 "00000000"
#define REDIS_GIT_DIRTY "0"
#define REDIS_BUILD_ID "bazel"
#include "version.h"
#define REDIS_BUILD_ID_RAW SERVER_NAME VALKEY_VERSION REDIS_BUILD_ID REDIS_GIT_DIRTY REDIS_GIT_SHA1
"""


def replace_once(path, text, old, new):
    if text.count(old) != 1:
        sys.exit(f"error: expected exactly one match in {path} for:\n{old}")
    return text.replace(old, new)


def patch_top_cmakelists(text):
    old = "cmake_minimum_required(VERSION 3.10)\n"
    return replace_once("CMakeLists.txt", text, old, old + (
        "\n"
        "# apple_support's cc toolchain puts a literal STRIP_DEBUG_SYMBOLS in its link flags for wrapped_clang, which rules_foreign_cc passes through\n"
        "# without the matching LINKED_BINARY= arg, so wrapped_clang ends up running `strip \"\"`\n"
        'set(CMAKE_USER_MAKE_RULES_OVERRIDE "${CMAKE_CURRENT_LIST_DIR}/cmake/BazelRulesOverride.cmake")\n'
    ))


def patch_valkey_setup(text):
    path = "cmake/Modules/ValkeySetup.cmake"
    old = '        add_valkey_server_compiler_options("-DUSE_JEMALLOC")\n'
    text = replace_once(path, text, old, old + (
        "        # BCR jemalloc is the same upstream 5.3.0 as deps/jemalloc, minus the header marker that gates active defrag\n"
        '        add_valkey_server_compiler_options("-DVALKEY_VENDORED_JEMALLOC=1")\n'
    ))
    text = replace_once(
        path,
        text,
        'include_directories("${CMAKE_SOURCE_DIR}/deps/jemalloc/include")',
        'include_directories("${JEMALLOC_INCLUDE_DIR}")',
    )
    text = replace_once(
        path,
        text,
        "# Generate release.h file (always)\n"
        "add_custom_target(\n"
        "    release_header\n"
        "    COMMAND sh -c '${CMAKE_SOURCE_DIR}/src/mkreleasehdr.sh'\n"
        '    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/src")\n',
        "# src/release.h is checked in by this patch; mkreleasehdr.sh always rewrites it in the sandbox, since outside a git repo\n"
        "# `git diff -- ../src ../deps` silently falls back to --no-index and diffs the two directories against each other\n"
        "add_custom_target(release_header)\n",
    )
    return replace_once(path, text, "unset(CMAKE_C_FLAGS CACHE)\n", "")


EDITS = {
    "CMakeLists.txt": patch_top_cmakelists,
    "cmake/BazelRulesOverride.cmake": lambda _: RULES_OVERRIDE,
    "cmake/Modules/ValkeySetup.cmake": patch_valkey_setup,
    "deps/jemalloc/CMakeLists.txt": lambda _: JEMALLOC_CMAKE,
    "src/release.h": lambda _: RELEASE_H,
}


def read_sources(tarball):
    with tarfile.open(fileobj=io.BytesIO(tarball)) as tar:
        prefix = tar.getmembers()[0].name.split("/")[0]
        files = {}
        for path in EDITS:
            try:
                member = tar.getmember(f"{prefix}/{path}")
            except KeyError:
                files[path] = None
                continue
            files[path] = tar.extractfile(member).read().decode()
        return files


def unified_diff(path, old, new):
    header = f"diff --git a/{path} b/{path}\n" + ("new file mode 100644\n" if old is None else "")
    return header + "".join(difflib.unified_diff(
        (old or "").splitlines(keepends=True),
        new.splitlines(keepends=True),
        fromfile="/dev/null" if old is None else f"a/{path}",
        tofile=f"b/{path}",
    ))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="any release in the series, e.g. 9.1.2")
    parser.add_argument("--tarball", type=Path, help="local copy of the release tarball; downloaded if omitted")
    args = parser.parse_args()

    m = re.fullmatch(r"(\d+)\.(\d+)\.\d+", args.version)
    if not m:
        sys.exit("error: version must look like 9.1.2")
    series = f"{m[1]}.{m[2]}"

    if args.tarball:
        tarball = args.tarball.read_bytes()
    else:
        url = f"https://github.com/valkey-io/valkey/archive/refs/tags/{args.version}.tar.gz"
        with urllib.request.urlopen(url) as resp:
            tarball = resp.read()

    sources = read_sources(tarball)
    patch = "".join(unified_diff(path, sources[path], edit(sources[path])) for path, edit in EDITS.items())

    PATCHES_DIR.mkdir(parents=True, exist_ok=True)
    out = PATCHES_DIR / f"{series}.patch"
    out.write_text(patch)
    print(f"wrote {out.relative_to(REPO_ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
