load("@//godot/private:godot.bzl", "godot_download_rule")

"""Download godot."""

def godot_repositories(*, repo_name = "rules_godot", name = "godot", version = "4.4", flavor = "stable", architecture = "x86_64", os = "linux", platform = "linux.64"):
    """Download godot.

    This requires scons within the PATH of the bazel daemon
    Version 4.5.2+dfsg-1 has been shown to work, from ubuntu
    """

    godot_download_rule(
        name = name,
        repo_name = repo_name,
        version = version,
        flavor = flavor,
        architecture = architecture,
        os = os,
        platform = platform,
    )
