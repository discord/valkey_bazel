"""A repository of aliases pointing at one versioned valkey repository."""

_TARGETS = [
    "valkey",
    "valkey-benchmark",
    "valkey-check-aof",
    "valkey-check-rdb",
    "valkey-cli",
    "valkey-sentinel",
    "valkey-server",
]

def _valkey_default_repo_impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", "".join([
        'alias(\n    name = "{name}",\n    actual = "@{repo}//:{name}",\n    visibility = ["//visibility:public"],\n)\n\n'.format(
            name = name,
            repo = repository_ctx.attr.target_repo,
        )
        for name in _TARGETS
    ]))

valkey_default_repo = repository_rule(
    implementation = _valkey_default_repo_impl,
    doc = "Aliases every public target of a versioned valkey repository.",
    attrs = {
        "target_repo": attr.string(mandatory = True, doc = "Apparent name of the versioned repository."),
    },
)
