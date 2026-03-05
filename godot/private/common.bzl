def get_patch_args(patch_strip):
    if patch_strip:
        return ["-p{}".format(patch_strip)]
    return []
