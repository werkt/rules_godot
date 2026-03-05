load("@bazel_tools//tools/build_defs/repo:utils.bzl", "patch")
load("@bazel_lib//lib:base64.bzl", _base64="base64")
load("@bazel_lib//lib:strings.bzl", _chr="chr", _ord="ord")
load("//godot/private:common.bzl", _get_patch_args="get_patch_args")
load("//godot/private:remote.bzl", _remote="remote")

def _config_platform(platform, os, arch):
    # paraphrasing _data/config_platforms.yml mapping
    if not platform:
        if arch == "x86_64":
            return "{os}.64".format(os=os)
        else:
            fail("unknown arch mapping: {arch}".format(arch=arch))
    return platform

def _hex(hex):
    if len(hex) != 1:
        fail(hex)
    o = _ord(hex)
    if hex >= 'a' and hex <= 'f':
        return 10 + o - _ord('a')
    if hex >= '0' and hex <= '9':
        return o - _ord('0')
    fail("unknown hex {}".format(hex))

def _byte(hex):
    if len(hex) != 2:
        fail(hex)
    return _hex(hex[0]) * 16 + _hex(hex[1])

def _b64(hex):
    data = ""
    for i in range(0, len(hex), 2):
        b = _byte(hex[i:i+2])
        data += _chr(b)
    return _base64.encode(data)

def _godot_download_impl(ctx):
    if not ctx.attr.os and not ctx.attr.arch:
        os, arch = detect_host_platform(ctx)
    else:
        if not ctx.attr.os:
            fail("arch set but os not set")
        if not ctx.attr.arch:
            fail("os set but arch not set")
        os, arch = ctx.attr.os, ctx.attr.arch

    platform = _config_platform(ctx.attr.platform, os, arch)

    version = ctx.attr.version
    flavor = ctx.attr.flavor
    if not flavor:
        flavor = "stable"
    versions = ctx.attr.versions

    if not version:
        if ctx.attr.patches:
            fail("a single version must be specified to apply patches")

    if not versions:
        # If versions was unspecified, download a full list of files.
        # If version was unspecified, pick the latest version.
        # Even if version was specified, we need to download the file list
        # to find the SHA-256 sum. If we don't have it, Bazel won't cache
        # the downloaded archive.
        if not version:
            ctx.report_progress("Finding latest Godot version")
        else:
            ctx.report_progress("Finding Godot")
        by_version = fetch_by_version(ctx)

        if not version:
            highest_version = None
            for v in by_version.keys():
                pv = parse_version(v)
                if not pv or _version_is_prerelease(pv, by_version[v]):
                    # skip parse errors and pre-release versions
                    continue
                if not highest_version or _version_less(highest_version, pv):
                    highest_version = pv
            if not highest_version:
                fail("did not find any Go versions in https://godotengine.org/versions.json")
            version = _version_string(highest_version, by_version[v])
        if version not in by_version:
            fail("did not find version {} in https://godotengine.org/versions.json, versions available were {}".format(version, by_version.keys()))
        versions = by_version[version]

    if flavor not in versions:
        fail("unsupported flavor {}, available are {}".format(flavor, versions))
    files = _sha512(ctx, ctx.attr.godotengine_urls, version, flavor)
    archive = "zip"

    #... refactor
    binary_query = {
        "version": version,
        "flavor": flavor,
        "slug": "%s.%s.%s" % (os, arch, archive),
        "platform": platform,
    }
    binary_filename = "Godot_v{version}-{flavor}_{os}.{arch}.{archive}".format(
        version = version,
        flavor = flavor,
        os = os,
        arch = arch,
        archive = archive)
    if binary_filename not in files:
        fail("no digest found for {}".format(binary_filename))
    _remote.download(
        ctx=ctx,
        unit="Binary",
        urls=[_remote.downloads_url(url, binary_query) for url in ctx.attr.downloads_urls],
        #strip_prefix=ctx.attr.strip_prefix,
        integrity="sha512-" + _b64(files[binary_filename]),
        type=archive)

    if ctx.attr.export_templates:
        # TODO make godot_binary fail if this isn't configured (vs. the build failure itself)
        export_templates_query = {
            "version": version,
            "flavor": flavor,
            "slug": "export_templates.tpz",
            "platform": "templates",
        }
        export_templates_filename = "Godot_v{version}-{flavor}_export_templates.tpz".format(
            version = version,
            flavor = flavor)
        if export_templates_filename not in files:
            fail("no digest found for {}".format(export_templates_filename))
        _remote.download(
            ctx=ctx,
            unit="Export Templates",
            urls=[_remote.downloads_url(url, export_templates_query) for url in ctx.attr.downloads_urls],
            #strip_prefix=ctx.attr.strip_prefix,
            integrity="sha512-" + _b64(files[export_templates_filename]),
            type=archive)

    patch(ctx, patch_args = _get_patch_args(ctx.attr.patch_strip))

    # wants to use contents in the release content to decide what version we are.
    # ./Godot_v4.4-stable_linux.x86_64 (could) be used, or we could execute it with --version, maybe, or we ignore this
    #detected_version = _detect_version(ctx, ".")
    detected_version = version
    # need to 'find latest flavor'?
    _files(
        ctx=ctx,
        repo_name=ctx.attr.repo_name,
        flavor=flavor,
        os=os,
        arch=arch,
        platform=platform,
        version=detected_version)

    if not ctx.attr.versions and not ctx.attr.version:
        # Returning this makes Bazel print a message that 'version' must be
        # specified for a reproducible build.
        return {
            "name": ctx.attr.name,
            "os": ctx.attr.os,
            "arch": ctx.attr.arch,
            "versions": ctx.attr.versions,
            "godotengine_urls": ctx.attr.godotengine_urls,
            "downloads_urls": ctx.attr.downloads_urls,
            "version": version,
            "strip_prefix": ctx.attr.strip_prefix,
        }

    if hasattr(ctx, "repo_metadata"):
        return ctx.repo_metadata(reproducible = True)
    else:
        return None


godot_download_rule = repository_rule(
    implementation = _godot_download_impl,
    attrs = {
        "flavor": attr.string(),
        "repo_name": attr.string(default="rules_godot"),
        "os": attr.string(),
        "arch": attr.string(),
        "platform": attr.string(),
        "versions": attr.string_list(),
        "godotengine_urls": attr.string_list(default = ["https://github.com/godotengine"]),
        "downloads_urls": attr.string_list(default = ["https://downloads.godotengine.org"]),
        "version": attr.string(),
        "strip_prefix": attr.string(default = "godot"),
        "export_templates": attr.bool(default=True),
        "patches": attr.label_list(
            doc = "A list of patches to apply to the repository after downloading it",
        ),
        "patch_strip": attr.int(
            default = 0,
            doc = "The number of leading path segments to be stripped from the file name in the patches.",
        ),
        "_build_file": attr.label(
            default = Label("//godot/private:BUILD.godot.bazel"),
        ),
        "_defs_file": attr.label(
            default = Label("//godot/private:defs.godot.bzl"),
        ),
    },
)

def _parse_versions_json(data):
    """Parses version metadata returned by godotengine.org.

    Args:
        data: the contents of the file downloaded from
            https://godotengine.org/versions.json. We assume the file is valid
            JSON, and is in a particular format.

    Return:
        A dict mapping version strings (like "1.15.5") to a list of flavor
        names (like "stable").
    """
    versions = json.decode(data)
    return {
        version["name"]: [
            file["name"]
            for file in version["releases"]
        ]
        for version in versions
    }

def fetch_by_version(ctx, allow_fail = False):
    result = ctx.download(
        url = [
            "https://godotengine.org/versions.json",
        ],
        output = "versions.json",
        allow_fail = allow_fail,
    )
    if not result.success:
        return None
    data = ctx.read("versions.json")

    # If the download is redirected through a proxy such as Artifactory, it may
    # drop the query parameters and return an HTML page instead. In that case,
    # just return an empty map if allow_fail is set. It is unfortunately not
    # possible to attempt parsing as JSON and catch the error.
    if (not data or data[0] != "[") and allow_fail:
        return None

    # module_ctx doesn't have delete, but its files are temporary anyway.
    if hasattr(ctx, "delete"):
        ctx.delete("versions.json")
    return _parse_versions_json(data)

def _parse_godot_json(data):
    """Parses version metadata maintained in godotengine/godot-builds.

    Args:
        data: the contents of the file downloaded from
            https://github.com/godotengine/godot-builds. We assume the file is valid
            JSON, and is in a particular format.

    Return:
        A dict of filenames to sha512 checksums. A repeated filename key will error.
    """
    files = json.decode(data)["files"]
    return {
        file["filename"]: file["checksum"]
        for file in files
    }

def _sha512(ctx, urls, version, flavor, repository = "godot-builds", branch = "main", allow_fail = False):
    url = [
        "{url}/{repository}/raw/refs/heads/{branch}/releases/godot-{version}-{flavor}.json".format(
            url = url,
            repository = repository,
            branch = branch,
            version = version,
            flavor = flavor)
        for url in urls
    ]
    result = ctx.download(
        url = url,
        output = "godot.json",
        allow_fail = allow_fail,
    )
    if not result.success:
        return None
    data = ctx.read("godot.json")

    if (not data or data[0] != "[") and allow_fail:
        return None

    if hasattr(ctx, "delete"):
        ctx.delete("godot.json")
    return _parse_godot_json(data)

def _files(*, ctx, repo_name, flavor, os, arch, platform, version):
    ctx.file("ROOT")

    substitutions = {
        "{name}": ctx.original_name,
        "{repo_name}": repo_name,
        "{export_templates}": ctx.original_name,
        "{export_templates_external}": ctx.name,
        "{flavor}": flavor,
        "{os}": os,
        "{arch}": arch,
        "{platform}": platform,
        "{exe}": ".exe" if os == "windows" else "",
        "{version}": version,
        "{visibility}": '["//visibility:public"]',
    }

    ctx.template(
        "BUILD.bazel",
        ctx.path(ctx.attr._build_file),
        executable = False,
        substitutions = substitutions,
    )

    ctx.template(
        "defs.bzl",
        ctx.path(ctx.attr._defs_file),
        executable = False,
        substitutions = substitutions,
    )

    ctx.file(
        "version.bzl",
        executable = False,
        content = _define_version_constants(version),
    )

def _define_version_constants(version, prefix = ""):
    pv = parse_version(version)
    if pv == None or len(pv) < 3:
        fail("error parsing version: " + version)
    major, minor, patch = pv[0], pv[1], pv[2]
    prerelease = pv[3] if len(pv) > 3 else ""
    return """
{prefix}MAJOR_VERSION = "{major}"
{prefix}MINOR_VERSION = "{minor}"
{prefix}PATCH_VERSION = "{patch}"
{prefix}PRERELEASE_SUFFIX = "{prerelease}"
""".format(
        prefix = prefix,
        major = major,
        minor = minor,
        patch = patch,
        prerelease = prerelease,
    )

def detect_host_platform(ctx):
    os = ctx.os.name
    if os == "mac os x":
        os = "darwin"
    elif os.startswith("windows"):
        os = "windows"

    arch = ctx.os.arch
    if arch == "aarch64":
        arch = "arm64"
    if arch == "amd64":
        arch = "x86_64"

    return os, arch

def parse_version(version):
    """Parses a version string like "1.15.5" and returns a tuple of numbers or None"""
    l, r = 0, 0
    parsed = []
    for c in version.elems():
        if c == ".":
            if l == r:
                # empty component
                return None
            parsed.append(int(version[l:r]))
            r += 1
            l = r
            continue

        if c.isdigit():
            r += 1
            continue

        # pre-release suffix
        break

    if l == r:
        # empty component
        return None
    parsed.append(int(version[l:r]))
    if len(parsed) == 2:
        # first minor version, like (1, 15)
        parsed.append(None)
    if len(parsed) != 3:
        # too many or too few components
        return None
    if r < len(version):
        # pre-release suffix
        parsed.append(version[r:])
    return tuple(parsed)

def _version_is_prerelease(v, flavors):
    if len(v) > 3:
        return True
    return "stable" not in flavors

def _version_less(a, b):
    a3 = [v if v else 0 for v in a]
    b3 = [v if v else 0 for v in b]
    if a3 < b3:
        return True
    if a3 > b3:
        return False
    if len(a) > len(b):
        return True
    if len(a) < len(b) or len(a) == 3:
        return False
    return a[3:] < b[3:]

def _version_string(v, flavors):
    suffix = v[3] if _version_is_prerelease(v, flavors) else ""
    return ".".join([str(n) for n in v if n != None]) + suffix

def _detect_version(ctx, root):
    ctx.execute(["find", root], quiet=False)
    fail("GOT HERE")
