local manifest = require("manifest")

local REASON = {
    ["head-drifted"] = "the SDK's git HEAD no longer matches the commit vfox installed",
    ["sdk-no-longer-git"] = "vfox can no longer read the SDK's git HEAD (its .git may be broken)"
}

local function printDriftWarning(sdkPath, version, manifestInfo, currentHead, reason)
    local installedVersion = (manifestInfo and manifestInfo.version) or version
    local expectedHead = (manifestInfo and manifestInfo.expected_head) or "unknown"
    io.write(string.format(
        [[
Warning: flutter SDK at %s has drifted from the version vfox installed.
  vfox installed: flutter@%s (git HEAD %s)
  current git HEAD: %s
  reason: %s

This typically happens when `flutter upgrade` or a similar in-place command
is run inside a vfox-managed SDK. vfox manages SDK versions by directory and
does not track in-place mutations, so the version you get may differ from
the one you asked for.

To restore flutter@%s:
  vfox uninstall flutter@%s
  vfox install  flutter@%s
  vfox use      flutter@%s

To upgrade to a newer version, use vfox directly:
  vfox install flutter@<new-version>
  vfox use     flutter@<new-version>
]],
        sdkPath,
        installedVersion,
        expectedHead,
        currentHead or "unknown",
        REASON[reason] or reason,
        version,
        version,
        version,
        version
    ))
end

function PLUGIN:PreUse(ctx)
    local sdk = ctx.installedSdks and ctx.installedSdks[ctx.version]
    if sdk == nil or sdk.path == nil or sdk.path == "" then
        return { version = ctx.version }
    end
    local drifted, reason = manifest.checkDrift(sdk.path)
    if drifted then
        printDriftWarning(sdk.path, ctx.version, manifest.read(sdk.path), manifest.currentHead(sdk.path), reason)
    end
    return { version = ctx.version }
end
