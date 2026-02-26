"""Download godot."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

GODOT_GITHUB = "https://github.com/godotengine"
GODOT_DOWNLOADS = "https://downloads.godotengine.org"
GODOT_DIGESTS = {
    "4.4": {
        "stable": {
            "godot-cpp-sha256": "0d64106ce1e09547f6054743b6fb9db903f23f27d1e669c7556a0a02669bd9ba",
            "godot-sha256-x86_64-linux.64": "05d2c4d6f9b52a620df4b8b9bdd5113a1a53ea83f6edd16042d609fd24ec75a4",
            "godot-export-templates-sha256-x86_64-linux.64": "70b6b98b1a5502c01e2aca18e8e567bf044eed8b49d0deb75dfdfca573fe52f8",
        },
    },
    "4.5": {
        "stable": {
            "godot-cpp-sha256": "0316ea168750b5f4f1caea6457657a6c64241f890f78e2f042aee4be2b1085bf",
            "godot-sha256-x86_64-linux.64": "c7316e1fd782ad276a4d985a7673b5976eaaa8d90561a2bea5289210dc53e9ba",
            "godot-export-templates-sha256-x86_64-linux.64": "375d83b661794f91746d2dec9b569a99d4d24f85a70c4ec0068aafb18b551d53",
        },
    },
}

def _gh_godotengine(*, repository, id, bucket = "tags", archive = "zip", **kwargs):
    return "%s/%s/archive/refs/%s/%s.%s" % (GODOT_GITHUB, repository, bucket, id, archive)

def _dl_godotengine(query):
    query_string = "&".join(["%s=%s" % pair for pair in query.items()])
    return "%s/?%s" % (GODOT_DOWNLOADS, query_string)

def _godot_cpp(*, name, version, flavor, sha256, **kwargs):
    id = "godot-%s-%s" % (version, flavor)
    http_archive(
        name = name,
        urls = [
            _gh_godotengine(repository = "godot-cpp", id = id, **kwargs),
        ],
        build_file = "//:godot-cpp-%s.BUILD" % version,
        patch_cmds = [
            "scons build_library=no", # generate the srcs and hdrs into "gen"
        ],
        sha256 = sha256,
        strip_prefix = "godot-cpp-%s" % id,
    )

def _godot_binary(*, name, version, flavor, architecture, os, platform, sha256, archive = "zip"):
    query = {
        "version": version,
        "flavor": flavor,
        "slug": "%s.%s.%s" % (os, architecture, archive),
        "platform": platform,
    }
    http_archive(
        name = name,
        urls = [_dl_godotengine(query)],
        type = archive,
        sha256 = sha256,
        build_file_content = """
filegroup(
    name = "godot",
    srcs = ["Godot_v%s-%s_%s.%s"],
    visibility = ["//visibility:public"],
)""" % (version, flavor, os, architecture),
    )

def _godot_export_templates(*, name, version, flavor, sha256, archive = "zip", **kwargs):
    query = {
        "version": version,
        "flavor": flavor,
        "slug": "export_templates.tpz",
        "platform": "templates",
    }
    http_archive(
        name = name,
        urls = [_dl_godotengine(query)],
        sha256 = sha256,
        type = archive,
        build_file = "//:godot-export-templates.BUILD",
    )

def _sha256(name, *, architecture = None, platform = None, **kwargs):
    key = "%s-sha256" % name
    if architecture and platform:
        key += "-%s-%s" % (architecture, platform)
    return key

def _godot_impl(repository_ctx):
    a = repository_ctx.attr
    # generate a toplevel defs.bzl
    repository_ctx.file("BUILD.bazel",
        content = """
alias(
    name = "godot",
    actual = "@%s-binary//:godot",
    visibility = ["//visibility:public"],
)""" % a.name,
        executable = False,
    )
    # need to get the name of the _current_ repo from whence we are
    repository_ctx.file(
        "defs.bzl", 
        content = """
load("@%s//:defs.bzl", _godot_binary = "godot_binary")

def godot_binary(*, version = None, flavor = None, **kwargs):
    if version or flavor:
        fail("specified version or flavor in wrapped godot_binary")
    _godot_binary(
        version = "%s",
        flavor = "%s",
        repo_name = "%s",
        export_templates = "%s-export-templates",
        **kwargs)
""" % (a.repo_name, a.version, a.flavor, a.name, a.name),
       executable = False,
    )

_godot = repository_rule(
    implementation = _godot_impl,
    attrs = {
        "repo_name": attr.string(mandatory=True),
        "version": attr.string(mandatory=True),
        "flavor": attr.string(mandatory=True),
        "architecture": attr.string(mandatory=True),
        "os": attr.string(mandatory=True),
        "platform": attr.string(mandatory=True),
    },
)

def godot_repositories(*, repo_name = "rules_godot", name = "godot", version = "4.4", flavor = "stable", architecture = "x86_64", os = "linux", platform = "linux.64"):
    """Download godot.

    This requires scons within the PATH of the bazel daemon
    Version 4.5.2+dfsg-1 has been shown to work, from ubuntu
    """

    digests = GODOT_DIGESTS[version][flavor]

    common = {
        "version": version,
        "flavor": flavor,
        "architecture": architecture,
        "os": os,
        "platform": platform,
    }

    _godot_cpp(
        name = "%s-cpp" % name,
        sha256 = digests[_sha256(name = "godot-cpp")],
        **common,
    )

    _godot_binary(
        name = "%s-binary" % name,
        sha256 = digests[_sha256(name = "godot", **common)],
        **common,
    )

    _godot_export_templates(
        name = "%s-export-templates" % name,
        sha256 = digests[_sha256(name = "godot-export-templates", **common)],
        **common,
    )

    _godot(
        name = name,
        repo_name = repo_name,
        **common
    )
