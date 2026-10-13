# Valkey On Bazel

Builds [Valkey](https://valkey.io) from source with Bazel, via `rules_foreign_cc` and Valkey's own CMake build.

- Multiple Valkey versions can be configured concurrently.
- jemalloc comes from the [BCR jemalloc module](https://registry.bazel.build/modules/jemalloc) rather than Valkey's vendored copy, configured the same way Valkey's own build configures it.

**beep boop** this is mostly robot generated. PRs making this more human friendly are welcome.

## Usage

```bazel
bazel_dep(name = "valkey_bazel")
git_override(
    module_name = "valkey_bazel",
    commit = "<commit>",
    remote = "<remote>",
    strip_prefix = "valkey_bazel",
)

valkey = use_extension("@valkey_bazel//:extension.bzl", "valkey")
valkey.add_version(repo_name = "valkey_8", version = "8.1.10")
valkey.add_version(version = "9.1.2")
valkey.default_version(repo_name = "my_valkey", version = "9.1.2")
use_repo(valkey, "my_valkey", "valkey_8", "valkey_9_1_2")
```

Then run or depend on what you need:

```
bazel run @valkey_9_1_2//:valkey-server -- --port 6380
```

### Available Versions

Every 8.1.x, 9.0.x and 9.1.x release. See [versions.bzl](./valkey_bazel/versions.bzl) for a complete list.

7.2.x and 8.0.x are not supported: Valkey only gained a CMake build in 8.1.0.

### Available Targets

Binaries, all runnable with `bazel run`:

* `valkey-benchmark`
* `valkey-check-aof`
* `valkey-check-rdb`
* `valkey-cli`
* `valkey-sentinel`
* `valkey-server`

`valkey-sentinel`, `valkey-check-aof` and `valkey-check-rdb` are `valkey-server` under another name, the same way upstream installs them; the server picks its mode from the name it is invoked as.

`valkey` is the underlying `rules_foreign_cc` `cmake()` target.

### Extension API

`add_version`:
  * `repo_name`: The name of the repo to export. Defaults to `valkey_<major>_<minor>_<patch>`
  * `version`: The version to use. Unless `url` + `sha256` are specified, this must be present in `valkey_bazel/versions.bzl`
  * `url`: The url to Valkey source for this version. Requires `sha256` if set.
  * `sha256`: The hash of the file at `url`. Invalid if `url` is not specified.
  * `series`: The release series whose patch to apply, e.g. `9.1`. Defaults to the version's own major.minor.

`default_version`:
  * `repo_name`: The name of the repo to export. Defaults to `valkey`
  * `version`: The version to alias to. This must be specified in an `add_version()` call.

### Testing a version

`valkey_smoke_test` starts a server on a unix socket, runs commands (including Lua and active defrag) through `valkey-cli`, runs a short `valkey-benchmark`, saves and verifies the RDB with `valkey-check-rdb`, and shuts the server down:

```bazel
load("@valkey_bazel//:defs.bzl", "valkey_smoke_test")

valkey_smoke_test(
    name = "valkey_9_1_2_smoke_test",
    repo = "@valkey_9_1_2",
    version = "9.1.2",
)
```

To run a full integration test like CI does, run `./scripts/test.sh` from the repository root. It builds every version in versions.bzl and smoke tests it.

## Adding a version

Run `./scripts/add_version.py <version>`. It pins the tarball's sha256 in `versions.bzl` and regenerates `valkey_test_builds/` so CI smoke tests it.

The first release of a new series (e.g. 9.2.0) also needs `valkey_bazel/patches/<series>.patch`; `add_version.py` generates one with `scripts/make_patch.py` if it's missing. That script applies the same edits to every series and fails loudly if upstream has moved the code it edits, at which point the edits in `make_patch.py` need updating.

## What the patches change

Each series' patch makes Valkey's CMake build behave under Bazel:

* Keeps the toolchain's C flags. Upstream's `ValkeySetup.cmake` unsets `CMAKE_C_FLAGS` from the cache, which silently drops the flags `rules_foreign_cc` passes in from the cc toolchain (sysroots, targets, etc.)
* Removes a literal `STRIP_DEBUG_SYMBOLS` from the link flags. apple_support's toolchain adds it for its `wrapped_clang` wrapper, which `rules_foreign_cc` passes through without the matching `LINKED_BINARY=` argument, so every link would end in `strip ""`.
* Uses jemalloc from Bazel instead of running jemalloc's `./configure && make` inside the source tree at configure time, and defines `VALKEY_VENDORED_JEMALLOC` so active defrag stays enabled (the BCR module is the same upstream 5.3.0 Valkey vendors).
* Ships a fixed `src/release.h` and skips `mkreleasehdr.sh`, which would otherwise rewrite it in the read-only source tree on every build.

The build also passes `PYTHON_EXE=OFF` so CMake doesn't regenerate the checked-in `commands.def` and `fmtargs.h` in the source tree.
