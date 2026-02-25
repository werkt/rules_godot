filegroup(
    name = "srcs",
    srcs = glob(["**"]),
)

cc_library(
    name = "godot-cpp",
    srcs = glob([
        "src/*.cpp",
        "src/classes/*.cpp",
        "src/core/*.cpp",
        "src/variant/*.cpp",
        "gen/src/classes/*.cpp",
        "gen/src/variant/*.cpp",
    ]),
    hdrs = glob([
        "include/**/*.hpp",
        "include/**/*.inc",
        "gen/include/**/*.hpp",
        "gdextension/**/*.h",
    ]),
    includes = [
        "gdextension",
        "gen/include",
        "include",
    ],
    linkstatic = True,
    visibility = ["//visibility:public"],
)
