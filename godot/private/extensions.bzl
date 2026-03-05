load("@com_github_rules_godot_bazel_features//:features.bzl", "bazel_features")
load("//godot/private:godot.bzl", "fetch_by_version", "godot_download_rule")
load("//godot/private:cpp.bzl", "godot_cpp_rule")

def _godot_impl(ctx):
    all_by_version = {}
    used_by_version = {}
    facts = getattr(ctx, "facts", {})

    multi_version_module = {}
    for module in ctx.modules:
        if module.name in multi_version_module:
            multi_version_module[module.name] = True
        else:
            multi_version_module[module.name] = False

    def get_by_version_cached(version):
        versions = facts.get(version)
        if versions == None:
            if not all_by_version:
                all_by_version.clear()
                all_by_version.update(fetch_by_version(ctx, allow_fail = True) or {
                    "fetch_failed_but_should_not_fetch_again_sentinel": [],
                })
            versions = all_by_version.get(version)
        if versions == None:
            return None
        used_by_version[version] = versions
        return versions

    for module in ctx.modules:
        for index, download_tag in enumerate(module.tags.download):
            if not module.is_root and not download_tag.version:
                fail("godot.download: version must be specified in non-root module " + module.name)
            if (not module.is_root and not module.name == "rules_godot") and download_tag.name:
                fail("godot.download: name must not be specified in non-root module " + module.name)

            name = download_tag.name or _default_godot_name(
                module = module,
                multi_version = multi_version_module[module.name],
                tag_type = "download",
                index = index,
            )

            _download(
                get_versions = get_by_version_cached,
                name = name,
                repo_name = download_tag.repo_name,
                flavor = download_tag.flavor,
                arch = download_tag.arch,
                os = download_tag.os,
                platform = download_tag.platform,
                download_tag = download_tag,
            )

        for index, cpp_tag in enumerate(module.tags.cpp):
            if not module.is_root and not cpp_tag.version:
                fail("godot.cpp: version must be specified in non-root module " + module.name)
            if (not module.is_root and not module.name == "rules_godot") and cpp_tag.name:
                fail("godot.cpp: name must not be specified in non-root module " + module.name)

            name = cpp_tag.name or _default_godot_name(
                module = module,
                multi_version = multi_version_module[module.name],
                tag_type = "cpp",
                index = index,
           )

            _cpp(
                name = name,
                version = cpp_tag.version,
                flavor = cpp_tag.flavor,
                type = cpp_tag.type,
                cpp_tag = cpp_tag,
            )

    if bazel_features.external_deps.extension_metadata_has_reproducible:
        kwargs = {
            "reproducible": True,
        }

        if hasattr(ctx, "facts"):
            kwargs["facts"] = used_by_version
        return ctx.extension_metadata(**kwargs)
    else:
        return None

def _default_godot_name(*, module, multi_version, tag_type, index, suffix = ""):
    # Keep the version and name of the root module out of the repository name if possible to
    # prevent unnecessary rebuilds when it changes.
    return "{name}_{version}_{tag_type}_{index}{suffix}".format(
        # "main_" is not a valid module name and thus can't collide.
        name = "main_" if module.is_root else module.name,
        version = module.version if multi_version else "",
        tag_type = tag_type,
        index = index,
        suffix = suffix,
    )

godot_extra_kwargs = {
    "os_dependent": True,
    "arch_dependent": True,
} if bazel_features.external_deps.module_extension_has_os_arch_dependent else {}

_COMMON_TAG_ATTRS = {
    "name": attr.string(),
    "os": attr.string(),
    "arch": attr.string(),
    "versions": attr.string_list_dict(),
    "godotengine_urls": attr.string_list(default = ["https://github.com/godotengine"]),
    "downloads_urls": attr.string_list(default = ["https://downloads.godotengine.org"]),
    "patches": attr.label_list(
        doc = "A list of patches to apply to the repository after downloading it",
    ),
    "patch_strip": attr.int(
        default = 0,
        doc = "The number of leading path segments to be stripped from the file name in the patches.",
    ),
    "strip_prefix": attr.string(default = "godot"),
}

_download_tag = tag_class(
    doc = """Download a specific Godot.""",
    attrs = _COMMON_TAG_ATTRS | {
        "version": attr.string(),
        "repo_name": attr.string(default="rules_godot"),
        "flavor": attr.string(),
        "arch": attr.string(),
        "os": attr.string(),
        "platform": attr.string(),
        "export_templates": attr.bool(default=True),
    },
)

_cpp_tag = tag_class(
    doc = """Download a specific godot-cpp.""",
    attrs = _COMMON_TAG_ATTRS | {
        "version": attr.string(),
        "type": attr.string(default="tag"),
        "flavor": attr.string(default="stable"),
    },
)

def _download(*, get_versions, name, repo_name, flavor, arch, os, platform, download_tag):
    version = download_tag.version
    versions = download_tag.versions
    if version and not versions:
        versions = get_versions(version)

    godot_download_rule(
        name = name,
        repo_name = repo_name,
        flavor = flavor,
        os = os,
        arch = arch,
        platform = platform,
        versions = versions,
        patches = download_tag.patches,
        patch_strip = download_tag.patch_strip,
        godotengine_urls = download_tag.godotengine_urls,
        downloads_urls = download_tag.downloads_urls,
        version = download_tag.version,
        strip_prefix = download_tag.strip_prefix,
    )

def _cpp(*, name, version, flavor, type, cpp_tag):
    godot_cpp_rule(
        name = name,
        version = version,
        type = type,
        flavor = flavor,
        patches = cpp_tag.patches,
        patch_strip = cpp_tag.patch_strip,
        godotengine_urls = cpp_tag.godotengine_urls,
        strip_prefix = cpp_tag.strip_prefix,
    )

godot = module_extension(
    implementation = _godot_impl,
    tag_classes = {
        "download": _download_tag,
        "cpp": _cpp_tag,
    },
    **godot_extra_kwargs,
)
