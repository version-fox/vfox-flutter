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

require("util")

local REPO = "flutter/flutter"
local CLONE_URL = "https://github.com/%s.git"

local SOURCE_INSTALL_PLATFORMS = {
    ["linux/arm64"] = true,
    ["windows/arm64"] = true,
}

-- The oldest release whose Flutter tool runs with a native Dart SDK on the machine, so that an
-- `-arm64` source install is what its name says. The tool downloads the Dart SDK on its first
-- run, and it takes the arm64 one only when two things hold: the release's own bootstrap script
-- (bin/internal/update_dart_sdk.sh, update_dart_sdk.ps1 on Windows) asks for it, and Flutter's
-- storage has it (flutter_infra_release/flutter/<engine revision>/dart-sdk-<os>-arm64.zip).
-- Checked on 2026-10-21 for the 300 releases that have an x64 build, 1.20.0 to 3.50.0-0.1.pre:
--   Linux: the script asks for the x64 SDK up to 2.0.6, which an ARM64 machine does not run, and
--   for the arm64 one from 2.2.0 on. Storage has the arm64 SDK from 2.0.0 on.
--   Windows: the script asks for the arm64 SDK from 3.20.0-1.1.pre on, and falls back to the x64
--   one, which Windows runs through its emulation, when storage has none. Storage has it from
--   3.44.0-0.1.pre on, and for seven older betas (3.11.0-0.0.pre, 3.17.0-0.0.pre,
--   3.18.0-0.1.pre, 3.19.0-0.1.pre, 3.20.0-1.1.pre, 3.21.0-0.0.pre and 3.30.0-0.1.pre), of which
--   the first four are older than the script that would use it. The three that run natively are
--   left out with the rest.
-- Older releases keep their x64 archives; this decides which releases get an `-arm64` name.
local OLDEST_NATIVE = {
    ["linux/arm64"] = "2.2.0",
    ["windows/arm64"] = "3.44.0-0.1.pre",
}

local M = {}

function M.repoUrl()
    return CLONE_URL:format(REPO)
end

function M.supports(osType, archType)
    return SOURCE_INSTALL_PLATFORMS[osType .. "/" .. archType] == true
end

function M.list(releases, osType, archType)
    local oldest = OLDEST_NATIVE[tostring(osType) .. "/" .. tostring(archType)]
    local result = {}
    for _, info in ipairs(releases or {}) do
        if
            type(info.version) == "string"
            and string.sub(info.version, 1, 1) ~= "v"
            and info.dart_sdk_arch == "x64"
            and (oldest == nil or compare_versions(info.version, oldest) >= 0)
        then
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
