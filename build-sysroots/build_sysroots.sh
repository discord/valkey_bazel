#!/bin/bash

set -euo pipefail

build_platform() {
  platform="$1"
  dest="$2"

  bazel --quiet build @jammy-sysroot//:flat --platforms "$platform" --incompatible_strict_action_env
  tarball_path=$(bazel --quiet cquery @jammy-sysroot//:flat --platforms "$platform"  --output files --incompatible_strict_action_env)
  cp -pvf "$tarball_path" "$dest"
}

build_platform //:linux_amd64 ../sysroots/sysroot-linux-amd64.tar
build_platform //:linux_arm64 ../sysroots/sysroot-linux-arm64.tar
