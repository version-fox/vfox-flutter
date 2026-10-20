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
local ohos = require("ohos")
local source = require("source")

local MAX_ATTEMPTS = 3
local RETRY_DELAY = 5

require("util")
local function releases(platform)
    local resp, err
    for attempt = 1, MAX_ATTEMPTS do
        resp, err = http.get({ url = getReleasesUrl(platform.osType) })
        if resp ~= nil and resp.status_code == 200 then
            return json.decode(resp.body)
        end
        if attempt < MAX_ATTEMPTS then
            sleep(RETRY_DELAY)
        end
    end
    error("get version failed: " .. tostring(err) .. " (status " .. tostring(resp and resp.status_code) .. ")")
end

-- The index lists some releases more than once. A release that was promoted from one channel to
-- another has an archive in each. One that was published again has the same archive under two
-- checksums, and only the newest entry has the checksum of the file that is there now: the older
-- one fails the verification of the download. Keep the newest entry of each archive of a
-- version, in the order the index has them. Different versions never merge.
local function newestPublications(entries)
    local newest, order = {}, {}
    for _, info in ipairs(entries) do
        local key = info.archive and (info.version .. "|" .. info.archive) or info
        local seen = newest[key]
        if seen == nil then
            newest[key] = info
            table.insert(order, key)
        elseif (info.release_date or "") > (seen.release_date or "") then
            newest[key] = info
        end
    end
    local result = {}
    for _, key in ipairs(order) do
        table.insert(result, newest[key])
    end
    return result
end

-- The list `vfox search` shows, and `vfox install flutter@latest` takes the first line of.
-- PreInstall asks for the official releases only (ctx.officialOnly): installing one has no use
-- for the OpenHarmony list, and must not wait for gitcode.com to answer it.
function PLUGIN:Available(ctx)
    local platform = getOsTypeAndArch()
    local body = releases(platform)
    local kept = {}
    for _, info in ipairs(body.releases) do
        local oldVersion = string.sub(info.version, 1, 1) == "v"
        if oldVersion then
            break
        end
        table.insert(kept, info)
    end
    kept = newestPublications(kept)
    local result = {}
    for _, info in ipairs(kept) do
        local version = info.version
        local dartArch = info.dart_sdk_arch
        version = dartArch and (version .. "-" .. dartArch) or version
        table.insert(result, {
            version = version,
            url = getStorageBaseUrl() .. "/flutter_infra_release/releases/" .. info.archive,
            sha256 = info.sha256,
            key = info.hash,
            note = info.channel,
            addition = {
                {
                    name = "dart",
                    version = info.dart_sdk_version,
                },
            },
        })
    end
    if not (type(ctx) == "table" and ctx.officialOnly) then
        local listed, err = ohos.list()
        if listed == nil then
            io.stderr:write(
                "Warning: the OpenHarmony releases could not be read from gitcode.com ("
                    .. tostring(err)
                    .. "), so only the official releases are listed.\n"
            )
        else
            for _, info in ipairs(listed) do
                table.insert(result, info)
            end
        end
    end
    if source.supports(platform.osType, platform.archType) then
        for _, info in ipairs(source.list(kept, platform.osType, platform.archType)) do
            table.insert(result, info)
        end
    end
    table.sort(result, function(a, b)
        local aOhos = ohos.isOhosVersion(a.version)
        local bOhos = ohos.isOhosVersion(b.version)
        if aOhos ~= bOhos then
            return bOhos
        end
        -- Keep the default architecture first, including legacy releases with
        -- no architecture metadata, so @latest cannot select a foreign build.
        local _, aArch = splitVersionAndArch(a.version)
        local _, bArch = splitVersionAndArch(b.version)
        local aDefault = aArch == nil or aArch == platform.archType
        local bDefault = bArch == nil or bArch == platform.archType
        if aDefault ~= bDefault then
            return aDefault
        end
        -- Stable releases before pre-releases, so @latest is the newest stable release and
        -- not a beta that happens to have a higher number.
        local aStable = a.note == "stable"
        local bStable = b.note == "stable"
        if aStable ~= bStable then
            return aStable
        end
        local order = compare_versions(a.version, b.version)
        if order ~= 0 then
            return order > 0
        end
        local aNative = aArch == platform.archType
        local bNative = bArch == platform.archType
        if aNative ~= bNative then
            return aNative
        end
        if a.version ~= b.version then
            return a.version < b.version
        end
        -- The same name in two channels (a release promoted from beta to stable, or from dev to
        -- beta): a fixed order, so that equal entries do not come out in a different one
        -- whenever the rest of the list changes.
        return (a.note or "") < (b.note or "")
    end)
    return result
end
