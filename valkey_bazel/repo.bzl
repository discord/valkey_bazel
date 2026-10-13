"""Repository rule that fetches one Valkey release and makes it buildable."""

def _valkey_repo_impl(repository_ctx):
    version = repository_ctx.attr.version
    repository_ctx.download_and_extract(
        url = repository_ctx.attr.url,
        sha256 = repository_ctx.attr.sha256,
        stripPrefix = "valkey-" + version,
    )
    repository_ctx.patch(repository_ctx.attr.patch, strip = 1)
    repository_ctx.file("BUILD.bazel", repository_ctx.read(repository_ctx.attr._build_file), executable = False)

valkey_repo = repository_rule(
    implementation = _valkey_repo_impl,
    doc = "Fetches a Valkey release, applies its series patch, and adds the BUILD file.",
    attrs = {
        "patch": attr.label(mandatory = True, doc = "The release series' patch."),
        "sha256": attr.string(mandatory = True),
        "url": attr.string(mandatory = True),
        "version": attr.string(mandatory = True, doc = "Release, e.g. \"9.1.2\"."),
        "_build_file": attr.label(default = "//templates:BUILD.bazel.template"),
    },
)
