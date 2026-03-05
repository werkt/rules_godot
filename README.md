Godot Rules for Bazel

# Getting Started

Use this library to:

1. Facilitate a Godot repository suite to build projects into binaries with export templates
1. Build gdextensions against matching godot-cpp version

## bzlmod

```
RULES_GODOT_COMMIT="<commit>"
bazel_dep(name="rules_godot", version=RULES_GODOT_COMMIT)

git_override(
    module_name = "rules_godot",
    remote = "https://github.com/werkt/rules_godot",
    commit = RULES_GODOT_COMMIT,
)

godot = use_extension("@rules_godot//godot:extensions.bzl", "godot")

godot.download()

use_repo(godot, "godot")
```

## WORKSPACE

```
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_godot",
    urls = ["https://github.com/werkt/rules_godot/archive/<commit>.zip"],
    sha256 = "<checksum of above>",
    strip_prefix = "rules_godot-<commit>",
)

load("@rules_godot//:repository.bzl", "godot_repositories")

godot_repositories()
```

This will create a repository named "godot" that will be pinned and provide rules for this instance of the godot development framework.

From an appropriate pinned commit reference point.

In the root of a godot project directory:

```
load("@godot//:defs.bzl", "godot_binary")

godot_binary(
    name = "my-godot-app",
    srcs = glob(["**"]),
)
```

Your project should contain:

an export profile targetting linux
  with the setting "Embed PCK" turned on

# Plugins

## bzlmod

To select and use a godot-cpp archive as well for building gdextensions C++ modules:

```
godot.cpp(name = "godot-cpp", version = "4.4")

use_repo(godot, "godot")
```

## WORKSPACE

```
load("@rules_godot//godot:cpp.bzl", "godot_cpp_rule")

godot_cpp_rule(name = "godot-cpp", version="4.4")
```

Create a cc_binary rule with `name = "<plugin-name>.so"` and `linkshared = True` that depends on `"@godot-cpp"`

Create a `<name>.gdextension` file in your project's `bin/` directory that identifies your plugin relatively by name:

```
[configuration]

entry_symbol = "plugin_entry_point"
compatibility_minimum = "4.1"
reloadable = true

[libraries]

; macos.debug = "./lib<name>.macos.template_debug.dylib"
; macos.release = "./lib<name>.macos.template_release.dylib"
; windows.debug.x86_32 = "./<name>.windows.template_debug.x86_32.dll"
; windows.release.x86_32 = "./<name>.windows.template_release.x86_32.dll"
; windows.debug.x86_64 = "./<name>.windows.template_debug.x86_64.dll"
; windows.release.x86_64 = "./<name>.windows.template_release.x86_64.dll"
linux.debug.x86_64 = "./lib<name>.linux.template_debug.x86_64.so"
; linux.release.x86_64 = "./lib<name>.linux.template_release.x86_64.so"
; linux.debug.arm64 = "./lib<name>.linux.template_debug.arm64.so"
; linux.release.arm64 = "./lib<name>.linux.template_release.arm64.so"
; linux.debug.rv64 = "./lib<name>.linux.template_debug.rv64.so"
; linux.release.rv64 = "./lib<name>.linux.template_release.rv64.so"
```

Add a plugin mapping for a `godot_binary` target into a path specified by the gdextensions file:

```
    plugins = {
        "//path/to:<plugin-name>.so": "bin/lib<name>.linux.template_debug.x86_64.so",
    },
```

Populating other configs as necessary.

# Testing rules_godot itself

Testing binary:

`bazel run //test/test-binary:godot-test`

Build artifacts can be mapped into the resource root for the project as targets with data deps and remapping

For editor import plugin:

A symlink in the workspace will provide the link to a populated plugin with:

`bazel build //test/plugins:all`

The test/test-plugin project will then use this plugin while in the editor with the GDExample node type, and during application debug play.

Testing plugin binary:

`bazel run //test/test-plugin:godot-plugin-test`
