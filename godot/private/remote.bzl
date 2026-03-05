load("@bazel_tools//tools/build_defs/repo:utils.bzl", "read_user_netrc", "use_netrc")

def _downloads_url(url, query):
    query_string = "&".join(["%s=%s" % pair for pair in query.items()])
    return "%s/?%s" % (url, query_string)

def _github_url(url, repository, id, bucket = "tags", archive = "zip", **kwargs):
    return "%s/%s/archive/refs/%s/%s.%s" % (url, repository, bucket, id, archive)


def _download(*, ctx, unit, urls, **kwargs):
    if len(urls) == 0:
        fail("no urls specified")
    ctx.report_progress("Downloading and extracting Godot {}".format(unit))

    auth = use_netrc(read_user_netrc(ctx), urls, {})
    ctx.download_and_extract(
        url = urls,
        auth = auth,
        **kwargs,
    )

remote = struct(
    downloads_url = _downloads_url,
    github_url = _github_url,
    download = _download,
)
