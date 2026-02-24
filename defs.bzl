load("@rules_pkg//:pkg.bzl", "pkg_tar")

"""godot_binary."""

GODOT_EXPORT_TEMPLATES_REPO = "godot-export-templates"
GODOT_VERSION_TAG = "4.4.stable"

def _genrule_dir(ctx):
    dirs = []
    for dir in ctx.attr.outs:
        dirs.append(ctx.actions.declare_directory(dir))
    command = ctx.attr.cmd.replace("$@", dirs[0].path).replace("$<", ctx.files.srcs[0].path)
    ctx.actions.run_shell(
        command = command,
        inputs = ctx.files.srcs,
        outputs = dirs,
    )
    return DefaultInfo(files = depset(dirs))

genrule_dir = rule(
    implementation = _genrule_dir,
    attrs = {
        "cmd": attr.string(),
        "outs": attr.string_list(),
        "srcs": attr.label_list(allow_files = True),
    },
)

def _godot_binary_impl(ctx):
    # ctx.srcs.short_path must be a single directory

    res = ctx.files.srcs[0].path
    godot = ctx.file._godot.path
    commands = [
        "mkdir -p %s/godot/{cache,feature_profiles}" % res,  # suppress some warnings/errors during build, possibly fatal
        # "export HOME=$PWD", # godot wants to see $HOME/.local/share/godot/export_templates populated, but it does not seem to do so in the sandbox
        "%s --import --headless %s/project.godot" % (godot, res),  # this step may not be necessary with the subsequent build
    ]

    binary = ctx.actions.declare_file(ctx.attr.name)

    commands.append("BUILD_MODE=1 %s --headless --quiet --export-debug Linux $(realpath %s) %s/project.godot" % (godot, binary.path, res))
    # The export procedure _will not copy the libraries output into the res://bin/ section of the packed export
    # It will, however, output the libraries specified into the directory of the binary path...
    # And for some reason the binary _will_ load the .so referenced from the binary directory
    # so we declare these as outputs and let the export procedure produce them
    plugins = [ctx.actions.declare_file(plugin) for plugin in ctx.attr.plugins]

    # TODO permit .PCK file to be included in outputs
    outputs = [binary] + plugins
    ctx.actions.run_shell(
        command = "; ".join(commands),
        inputs = ctx.files.srcs,
        tools = ctx.files._godot,
        outputs = outputs,
    )
    return DefaultInfo(files = depset(outputs), executable = binary)

_godot_binary = rule(
    implementation = _godot_binary_impl,
    executable = True,
    attrs = {
        "plugins": attr.string_list(),
        "srcs": attr.label_list(),
        "_godot": attr.label(default = "//:godot", allow_single_file = True),
    },
)

def godot_binary(
        name,
        *,
        srcs = [],
        plugins = {}):

    # godot has no concept of a "chained" project with "res" spanning multiple search directories
    # so that we can support generated content from the build root for a project, we construct the
    # working directory from provided srcs through a pkg_tar and extract
    remap_paths = {
        "external/%s/templates" % GODOT_EXPORT_TEMPLATES_REPO: "godot/export_templates/%s" % GODOT_VERSION_TAG,
    }
    plugin_names = []
    # translate plugin prefix from @repo//foo/bar:baz to external/repo/foo/bar/baz
    # the export will put all libraries referenced in .gdextensions into the output directory of the binary
    # so collect the plugin_names as basenames of the res filenames
    for plugin, res in plugins.items():
        src = plugin.replace("@", "external/").replace("//", "/").replace(":", "/")
        remap_paths[src] = res
        plugin_names.append(res.split("/")[-1])

    pkg_tar(
        name = "res_pkg",
        srcs = srcs + [
            "@%s//:srcs" % GODOT_EXPORT_TEMPLATES_REPO,
        ] + plugins.keys(),
        remap_paths = remap_paths,
        strip_prefix = ".",
    )

    genrule_dir(
        name = "res",
        srcs = [":res_pkg"],
        outs = ["res"],
        cmd = "mkdir -p $@; tar -C $@ -xf $<",
    )

    _godot_binary(
        name = name,
        srcs = [":res"],
        plugins = plugin_names,
    )
