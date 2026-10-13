load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")

def _sysroot_impl(repo_ctx):
    repo_ctx.extract(archive = repo_ctx.attr.tarball, output = "")
    repo_ctx.file("BUILD.bazel", 'filegroup(name = "files", srcs = glob(["**/*"]), visibility = ["//visibility:public"])')

_sysroot = repository_rule(implementation = _sysroot_impl, attrs = {"tarball": attr.label(mandatory = True, allow_files = True)})

def _sysroots_impl(module_ctx):
    root_module_direct_deps = []
    for mod in module_ctx.modules:
        if mod.is_root:
            for sysroot in mod.tags.sysroot:
                root_module_direct_deps.append(sysroot.module_name)
                _sysroot(name = sysroot.module_name, tarball = sysroot.tarball)

    return module_ctx.extension_metadata(reproducible = True, root_module_direct_deps = root_module_direct_deps, root_module_direct_dev_deps = [])

sysroots = module_extension(
    implementation = _sysroots_impl,
    tag_classes = {"sysroot": tag_class(attrs = {
        "module_name": attr.string(mandatory = True),
        "tarball": attr.label(mandatory = True, allow_files = True),
    })},
)
