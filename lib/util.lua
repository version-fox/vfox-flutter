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

local DEFAULT_STORAGE_BASE_URL = "https://storage.googleapis.com"

function sleep(seconds)
    if RUNTIME.osType == "windows" then
        os.execute("timeout /t " .. seconds .. " >NUL")
    else
        os.execute("sleep " .. seconds)
    end
end

function getStorageBaseUrl()
    local envUrl = os.getenv("FLUTTER_STORAGE_BASE_URL")
    if envUrl ~= nil and envUrl ~= "" then
        return envUrl:gsub("/$", "")
    end
    return DEFAULT_STORAGE_BASE_URL
end

function getReleasesUrl(osType)
    return getStorageBaseUrl() .. "/flutter_infra_release/releases/releases_" .. osType .. ".json"
end

function getOsTypeAndArch()
    local osType = RUNTIME.osType
    local archType = RUNTIME.archType
    if osType == "darwin" then
        osType = "macos"
    end
    if archType == "amd64" then
        archType = "x64"
    elseif archType == "arm64" then
        archType = "arm64"
    else
        error("flutter does not support the " .. archType .. " architecture")
    end
    return {
        osType = osType,
        archType = archType,
    }
end

function splitVersionAndArch(version)
    local base, arch = version:match("^(.+)%-(%w+)$")
    if arch == "x64" or arch == "arm64" then
        return base, arch
    end
    return version, nil
end

function compare_versions(v1, v2)
    v1 = splitVersionAndArch(v1)
    v2 = splitVersionAndArch(v2)
    local v1_parts = {}
    for part in string.gmatch(v1, "%d+") do
        table.insert(v1_parts, tonumber(part))
    end

    local v2_parts = {}
    for part in string.gmatch(v2, "%d+") do
        table.insert(v2_parts, tonumber(part))
    end

    for i = 1, math.max(#v1_parts, #v2_parts) do
        local v1_part = v1_parts[i] or math.huge
        local v2_part = v2_parts[i] or math.huge
        if v1_part > v2_part then
            return 1
        elseif v1_part < v2_part then
            return -1
        end
    end

    return 0
end

-- Whether the running vfox knows the Fingerprint hook (added in vfox 1.1.0
-- with `vfox link`, `vfox doctor`, aliases and `path.mode`). Older vfox
-- versions never load a hook file they do not know, so the plugin keeps its
-- own drift check for them and lets the core report drift on newer ones.
-- `runtimeVersion` is the `ctx.runtimeVersion` of the calling hook when it
-- has one; otherwise the global `RUNTIME.version` answers.
function supportsFingerprint(runtimeVersion)
    local v = runtimeVersion
    if v == nil or v == "" then
        v = (RUNTIME and RUNTIME.version) or ""
    end
    v = tostring(v):gsub("^v", "")
    local major, minor = v:match("^(%d+)%.(%d+)")
    if major == nil then
        return false
    end
    major, minor = tonumber(major), tonumber(minor)
    if major == nil or minor == nil then
        return false
    end
    return major > 1 or (major == 1 and minor >= 1)
end
