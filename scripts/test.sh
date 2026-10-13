#!/bin/bash

set -euo pipefail

SCRIPTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && echo "$PWD")
pushd "${SCRIPTS_DIR}/../build-sysroots"
./build_sysroots.sh
popd

cd "${SCRIPTS_DIR}/../valkey_test_builds"
bazel test //...
