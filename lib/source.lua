-- Copyright 2026 Han Li and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

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
        if type(info.version) == "string" and string.sub(info.version, 1, 1) ~= "v" and info.dart_sdk_arch == "x64" then
            table.insert(result, {
                version = info.version .. "-arm64",
                url = M.repoUrl(),
                key = info.hash,
                note = info.channel,
                source = true,
                addition = {
                    {
                        name = "dart",
                        version = info.dart_sdk_version,
                    },
                },
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
    local repoUrl = M.repoUrl()
    local cloneUrl = git.mirrorUrl(repoUrl)
    if cloneUrl ~= repoUrl then
        io.write(string.format("Using GitHub mirror %s\n", cloneUrl))
        io.flush()
    end
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
        url = dir,
    }
end

function M.clean(version)
    local dir = git.workDir(version)
    if dir ~= nil then
        git.removeDir(dir)
    end
end

return M
