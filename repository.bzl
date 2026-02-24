"""Download godot."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def godot_repositories():
    """Download godot.

    This requires scons within the PATH of the bazel daemon
    Version 4.5.2+dfsg-1 has been shown to work, from ubuntu
    """

    http_archive(
        name = "godot-cpp",
        urls = [
            "https://github.com/godotengine/godot-cpp/archive/refs/tags/godot-4.4-stable.zip",
        ],
        build_file = "//:godot-cpp.BUILD",
        patch_cmds = [
            "scons build_library=no",
        ],
        sha256 = "0d64106ce1e09547f6054743b6fb9db903f23f27d1e669c7556a0a02669bd9ba",
        strip_prefix = "godot-cpp-godot-4.4-stable",
    )

    http_archive(
        name = "godot",
        urls = [
            "https://downloads.godotengine.org/?version=4.4&flavor=stable&slug=linux.x86_64.zip&platform=linux.64",
        ],
        type = "zip",
        sha256 = "05d2c4d6f9b52a620df4b8b9bdd5113a1a53ea83f6edd16042d609fd24ec75a4",
        build_file = "//:godot.BUILD",
    )

    http_archive(
        name = "godot-export-templates",
        urls = [
            "https://downloads.godotengine.org/?version=4.4&flavor=stable&slug=export_templates.tpz&platform=templates",
        ],
        sha256 = "70b6b98b1a5502c01e2aca18e8e567bf044eed8b49d0deb75dfdfca573fe52f8",
        type = "zip",
        build_file = "//:godot-export-templates.BUILD",
    )
