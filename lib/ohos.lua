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
local git = require("git")

require("util")

-- The fork tags its releases `3.41.10-ohos-1.0.0`, and, since 2026-10-15, `3.41.9+ohos-1.0.2`.
local MARKERS = { "-ohos-", "+ohos-" }
local REPO = "CPF-Flutter/flutter_flutter"
local RELEASES_URL = "https://gitcode.com/api/v5/repos/%s/releases?per_page=100"
local CLONE_URL = "https://gitcode.com/%s.git"
local NOTE = "OpenHarmony"
-- Installing an OpenHarmony build cannot go on without the releases, so it waits for them:
-- five attempts, ten seconds apart. HTTP 429 (rate limited) waits progressively longer, so
-- installs can ride out short quota windows instead of failing immediately. Ordinary errors
-- keep the short delay: there is no window to wait out.
local INSTALL = { attempts = 5, delay = 10, rateLimited = { 30, 60, 120, 180 } }
-- Listing them only adds names to `vfox search`, and every command that lists versions would
-- wait along with it: two attempts, and HTTP 429 ends them, since a quota window lasts much
-- longer than a list is worth waiting for. The caller says the list is incomplete.
local LIST = { attempts = 2, delay = 2 }

local M = {}

function M.isOhosVersion(version)
    if type(version) ~= "string" then
        return false
    end
    for _, marker in ipairs(MARKERS) do
        if version:find(marker, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function isRateLimited(resp, err)
    return err == nil and resp ~= nil and resp.status_code == 429
end

local function releases(policy)
    local lastErr = "unknown error"
    for attempt = 1, policy.attempts do
        local resp, err = http.get({ url = RELEASES_URL:format(REPO) })
        if err == nil and resp ~= nil and resp.status_code == 200 then
            local body = json.decode(resp.body)
            if type(body) == "table" then
                return body
            end
            lastErr = "the releases response is not a JSON array"
        else
            lastErr = err or ("HTTP " .. tostring(resp and resp.status_code))
        end
        if attempt < policy.attempts then
            if isRateLimited(resp, err) then
                local waits = policy.rateLimited
                if waits == nil then
                    break
                end
                sleep(waits[attempt] or waits[#waits])
            else
                sleep(policy.delay)
            end
        end
    end
    return nil, lastErr
end

-- The OpenHarmony releases as `Available` entries, or nil and the reason when gitcode.com
-- does not answer.
function M.list()
    local body, err = releases(LIST)
    if body == nil then
        return nil, err
    end
    local result = {}
    for _, info in ipairs(body) do
        local version = info.tag_name
        if M.isOhosVersion(version) then
            table.insert(result, {
                version = version,
                url = CLONE_URL:format(REPO),
                key = version,
                note = NOTE,
            })
        end
    end
    return result
end

function M.checkout(version, requestedArch)
    if requestedArch ~= nil then
        error("flutter " .. version .. " has no architecture variants")
    end
    local commit
    local body, err = releases(INSTALL)
    if body == nil then
        error("OpenHarmony releases are unavailable from " .. RELEASES_URL:format(REPO) .. ": " .. tostring(err))
    end
    for _, info in ipairs(body) do
        if info.tag_name == version then
            commit = info.target_commitish
            break
        end
    end
    if commit == nil or commit == "" then
        error("flutter " .. version .. " is not an OpenHarmony release")
    end
    local dir = git.workDir(version)
    if dir == nil then
        error("cannot resolve the vfox home directory")
    end
    local cloneUrl = CLONE_URL:format(REPO)
    git.resetDir(dir)
    if not git.init(dir) then
        error("failed to initialize git in " .. dir .. " (is git installed?)")
    end
    if not git.fetch(dir, cloneUrl, commit) then
        error("failed to fetch " .. commit .. " from " .. cloneUrl)
    end
    if not git.checkoutHead(dir) then
        error("failed to check out " .. commit .. " in " .. dir)
    end
    if not git.hasEnginePin(dir) then
        error("the checkout at " .. commit .. " has no engine version pin")
    end
    return {
        version = version,
        url = dir,
        note = NOTE,
    }
end

function M.clean(version)
    local dir = git.workDir(version)
    if dir ~= nil then
        git.removeDir(dir)
    end
end

return M
