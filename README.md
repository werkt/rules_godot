Godot Rules for Bazel

# Getting Started

Use this library to:

1. Facilitate a Godot repository suite to build projects into binaries with export templates
1. Build gdextensions against matching godot-cpp version

```
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_godot",
    urls = ["https://github.com/werkt/rules_godot/archive/<commit>.zip"],
    sha256 = "<checksum of above>",
)

load("@rules_godot//:repository.bzl", "godot_repositories")

godot_repositories()
```

From an appropriate pinned commit reference point.

In the root of a godot project directory:

```
load("@rules_godot//:defs.bzl", "godot_binary")

godot_binary(
    name = "my-godot-app",
    srcs = glob(["**"]),
)
```

Your project should contain:

an export profile targetting linux
  with the setting "Embed PCK" turned on

Testing binary:

`bazel run //test/test-binary:godot-test`

Build artifacts can be mapped into the resource root for the project as targets with data deps and remapping

For editor import plugin:

A symlink in the workspace will provide the link to a populated plugin with:

`bazel build //test/plugins:all`

The test/test-plugin project will then use this plugin while in the editor with the GDExample node type, and during application debug play.

Testing plugin binary:

`bazel run //test/test-plugin:godot-plugin-test`
