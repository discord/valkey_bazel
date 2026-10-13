# build-sysroots

Simple repository that builds a sysroot for use by llvm in `../valkey_test_builds`. `./build_sysroots.sh` generates an ubuntu sysroot tarball (via rules_distroless) for arm64 and amd64, and then sticks them in `../sysroots`. `../valkey_test_builds` then uses the `../sysroots` dir in its LLVM configuration on linux.
