local git = require("git")

local REPO = "flutter/flutter"
local CLONE_URL = "https://github.com/%s.git"

local SOURCE_INSTALL_PLATFORMS = {
    ["linux/arm64"] = true,
    ["windows/arm64"] = true,
}

local M = {}

function M.repoUrl()
    return CLONE_URL:format(REPO)
end

function M.supports(osType, archType)
    return SOURCE_INSTALL_PLATFORMS[osType .. "/" .. archType] == true
end

function M.list(releases)
    local result = {}
    for _, info in ipairs(releases or {}) do
        if type(info.version) == "string" and string.sub(info.version, 1, 1) ~= "v"
            and info.dart_sdk_arch == "x64" then
            table.insert(result, {
                version = info.version .. "-arm64",
                url = M.repoUrl(),
                key = info.hash,
                note = info.channel,
                source = true,
                addition = {
                    {
                        name = "dart",
                        version = info.dart_sdk_version
                    }
                }
            })
        end
    end
    return result
end

function M.checkout(baseVersion, versionName)
    if type(baseVersion) ~= "string" or baseVersion == "" then
        return nil
    end
    if type(versionName) ~= "string" or versionName == "" then
        versionName = baseVersion
    end
    local dir = git.workDir(versionName)
    if dir == nil then
        error("cannot resolve the vfox home directory")
    end
    local cloneUrl = M.repoUrl()
    git.resetDir(dir)
    if not git.init(dir) then
        error("failed to initialize git in " .. dir .. " (is git installed?)")
    end
    if not git.fetch(dir, cloneUrl, "refs/tags/" .. baseVersion) then
        error("failed to fetch tag " .. baseVersion .. " from " .. cloneUrl)
    end
    if not git.checkoutHead(dir) then
        error("failed to check out " .. baseVersion .. " in " .. dir)
    end
    if not git.hasEnginePin(dir) then
        error("the checkout at " .. baseVersion .. " has no engine version pin")
    end
    return {
        version = versionName,
        url = dir
    }
end

function M.clean(version)
    local dir = git.workDir(version)
    if dir ~= nil then
        git.removeDir(dir)
    end
end

return M
