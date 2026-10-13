"""Test helpers consumers can run against any version this module builds."""

load("@rules_shell//shell:sh_test.bzl", "sh_test")

_BINARIES = [
    "valkey-server",
    "valkey-cli",
    "valkey-benchmark",
    "valkey-check-rdb",
]

def valkey_smoke_test(name, repo, version, **kwargs):
    """Start a server, exercise it through the cli, benchmark and check-rdb, shut it down.

    Args:
      name: target name.
      repo: the valkey repository to exercise, e.g. "@valkey_9_1_2".
      version: version the server is expected to report, e.g. "9.1.2".
      **kwargs: passed through to the underlying sh_test.
    """
    sh_test(
        name = name,
        size = kwargs.pop("size", "small"),
        srcs = ["@valkey_bazel//:smoke_test.sh"],
        args = [version] + ["$(rlocationpath {}//:{})".format(repo, b) for b in _BINARIES],
        data = ["{}//:{}".format(repo, b) for b in _BINARIES],
        deps = ["@bazel_tools//tools/bash/runfiles"],
        **kwargs
    )
