load("@{repo_name}//:defs.bzl", _godot_binary = "godot_binary")

def godot_binary(*, version = None, flavor = None, **kwargs):
    if version or flavor:
        fail("specified version or flavor in wrapped godot_binary")
    _godot_binary(
        version = "{version}",
        flavor = "{flavor}",
        repo_name = "{name}",
        export_templates = "{export_templates}",
        export_templates_external = "{export_templates_external}",
        **kwargs)
