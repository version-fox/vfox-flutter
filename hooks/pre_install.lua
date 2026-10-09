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

local http = require("http")
local json = require("json")
local manifest = require("manifest")
local ohos = require("ohos")
local source = require("source")

require("util")

function PLUGIN:PreInstall(ctx)
    local arg, requestedArch = splitVersionAndArch(ctx.version)
    if ohos.isOhosVersion(arg) then
        return ohos.checkout(arg, requestedArch)
    end
    local platform = getOsTypeAndArch()
    local targetArch = requestedArch or platform.archType
    local channelKey
    if arg == "beta" or arg == "dev" or arg == "stable" then
        local resp, err = http.get({
            url = getReleasesUrl(platform.osType),
        })
        if err ~= nil or resp.status_code ~= 200 then
            error("get version failed: " .. tostring(err) .. " (status " .. tostring(resp and resp.status_code) .. ")")
        end
        local body = json.decode(resp.body)
        channelKey = body.current_release[arg]
        if channelKey == nil then
            return nil
        end
    end

    local function package(info, version)
        local versionName = requestedArch and info.version or version
        if info.source then
            return source.checkout(version, versionName)
        end
        return {
            version = versionName,
            url = info.url,
            sha256 = info.sha256,
        }
    end

    local legacy
    for _, info in ipairs(self:Available({})) do
        local version, arch = splitVersionAndArch(info.version)
        local matches = channelKey and info.key == channelKey or (channelKey == nil and version == arg)
        if matches then
            if arch == targetArch then
                return package(info, version)
            elseif arch == nil and requestedArch == nil then
                -- Older releases have no architecture metadata. Preserve their
                -- existing behavior only for requests without an architecture.
                legacy = package(info, version)
            end
        end
    end
    return legacy
end

function PLUGIN:PostInstall(ctx)
    local sdk = ctx.sdkInfo and ctx.sdkInfo[PLUGIN.name]
    if sdk == nil then
        return
    end
    if sdk.path ~= nil and sdk.path ~= "" then
        pcall(manifest.write, sdk.path, sdk)
        pcall(manifest.touchPubspecLock, sdk.path)
    end
    if ohos.isOhosVersion(sdk.version) then
        ohos.clean(sdk.version)
        return
    end
    pcall(source.clean, sdk.version)
end
