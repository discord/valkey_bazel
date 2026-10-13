"""Module extension that fetches Valkey sources and makes them buildable.

    valkey = use_extension("@valkey_bazel//:extension.bzl", "valkey")
    valkey.add_version(version = "9.1.2")
    use_repo(valkey, "valkey_9_1_2")
"""

load(":default_repo.bzl", "valkey_default_repo")
load(":repo.bzl", "valkey_repo")
load(":versions.bzl", "VERSIONS")

def _default_repo_name(version):
    return "valkey_" + version.replace(".", "_")

def _valkey_impl(module_ctx):
    created = []
    repo_for_version = {}
    for module in module_ctx.modules:
        for tag in module.tags.add_version:
            name = tag.repo_name or _default_repo_name(tag.version)
            if name in created:
                fail("valkey: repository {} was already declared".format(name))

            if tag.url and not tag.sha256:
                fail("valkey: version {} set url without sha256".format(tag.version))
            if tag.sha256 and not tag.url:
                fail("valkey: version {} set sha256 without url; it is only used with url".format(tag.version))

            known = VERSIONS.get(tag.version)
            if not known and not tag.url:
                fail("valkey: unknown version {}. Known versions: {}. Pass url and sha256 to build one that isn't listed.".format(
                    tag.version,
                    ", ".join(VERSIONS),
                ))

            series = tag.series or (known.series if known else tag.version.rsplit(".", 1)[0])
            patch = Label("//patches:{}.patch".format(series))
            if not module_ctx.path(patch).exists:
                fail("valkey: no patches/{}.patch for version {}. Pass series to use another release series' patch.".format(
                    series,
                    tag.version,
                ))

            valkey_repo(
                name = name,
                patch = patch,
                sha256 = tag.sha256 or known.sha256,
                url = tag.url or known.url,
                version = tag.version,
            )
            created.append(name)
            repo_for_version.setdefault(tag.version, name)

    for module in module_ctx.modules:
        for tag in module.tags.default_version:
            if tag.repo_name in created:
                fail("valkey: repository {} was already declared".format(tag.repo_name))
            if tag.version not in repo_for_version:
                fail("valkey: default_version {} has no matching add_version. Added versions: {}".format(
                    tag.version,
                    ", ".join(sorted(repo_for_version)),
                ))
            valkey_default_repo(
                name = tag.repo_name,
                target_repo = repo_for_version[tag.version],
            )
            created.append(tag.repo_name)

    return module_ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = created,
        root_module_direct_dev_deps = [],
    )

valkey = module_extension(
    implementation = _valkey_impl,
    doc = "Creates one repository per requested Valkey version.",
    tag_classes = {
        "add_version": tag_class(
            doc = "Make a Valkey version available as @valkey_<version>.",
            attrs = {
                "version": attr.string(
                    mandatory = True,
                    doc = "Release to build, e.g. \"9.1.2\".",
                ),
                "repo_name": attr.string(
                    doc = "Repository name. Defaults to valkey_<version>, dots replaced by underscores.",
                ),
                "url": attr.string(
                    doc = "Tarball URL, overriding the one in versions.bzl. Requires sha256.",
                ),
                "sha256": attr.string(
                    doc = "Tarball sha256. Only used together with url.",
                ),
                "series": attr.string(
                    doc = "Release series whose patch to apply, e.g. \"9.1\". Defaults to this release's own major.minor.",
                ),
            },
        ),
        "default_version": tag_class(
            doc = "Alias an added version's targets under an unversioned repository name.",
            attrs = {
                "version": attr.string(
                    mandatory = True,
                    doc = "A version also passed to add_version, e.g. \"9.1.2\".",
                ),
                "repo_name": attr.string(
                    default = "valkey",
                    doc = "Repository name for the aliases.",
                ),
            },
        ),
    },
)
