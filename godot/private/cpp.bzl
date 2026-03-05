load("@bazel_tools//tools/build_defs/repo:utils.bzl", "patch")
load("//godot/private:common.bzl", _get_patch_args="get_patch_args")
load("//godot/private:remote.bzl", _remote="remote")

_CPP_SHA256 = {
    "4.4-stable": "0d64106ce1e09547f6054743b6fb9db903f23f27d1e669c7556a0a02669bd9ba",
    "4.5-stable": "0316ea168750b5f4f1caea6457657a6c64241f890f78e2f042aee4be2b1085bf",
}

def _godot_cpp_impl(ctx):
    version, flavor = ctx.attr.version, ctx.attr.flavor
    id = "{version}-{flavor}".format(version=version, flavor=flavor)

    # these branches are sparse, and typically work on more than just the advertised version
    sha256 = ctx.attr.sha256
    if not sha256 and ctx.attr.type == "tag":
        sha256 = _CPP_SHA256[id]
    if not sha256:
        print("not canonical")
        # need to indicate the canonical behavior
        
    _remote.download(
        ctx=ctx,
        unit="CPP",
        urls=[_remote.github_url(url, repository="godot-cpp", id="godot-{}".format(id)) for url in ctx.attr.godotengine_urls],
        strip_prefix="godot-cpp-godot-{}".format(id),
        sha256=sha256)

    # TODO declare the scons generation as a build action
    ctx.execute(["scons", "build_library=no"]) # generate the srcs and hdrs into "gen"

    patch(ctx, patch_args = _get_patch_args(ctx.attr.patch_strip))

    ctx.file(
        "BUILD.bazel",
        ctx.read(ctx.attr._build_file),
    )

godot_cpp_rule = repository_rule(
    implementation = _godot_cpp_impl,
    attrs = {
        "version": attr.string(mandatory = True),
        "flavor": attr.string(default = "stable"),
        "type": attr.string(default = "tag"),
        "sha256": attr.string(),
        "godotengine_urls": attr.string_list(default = ["https://github.com/godotengine"]),
        "strip_prefix": attr.string(default = "godot-cpp"),
        "patches": attr.label_list(
            doc = "A list of patches to apply to godot-cpp after downloading it",
        ),
        "patch_strip": attr.int(
            default = 0,
            doc = "The number of leading path segments to be stripped from the file name in the patches.",
        ),
        "_build_file": attr.label(
            default = Label("//godot/private:BUILD.cpp.bazel"),
        ),
    },
)
