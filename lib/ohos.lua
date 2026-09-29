local http = require("http")
local json = require("json")
local git = require("git")

require("util")

local MARKER = "-ohos-"
local REPO = "CPF-Flutter/flutter_flutter"
local RELEASES_URL = "https://gitcode.com/api/v5/repos/%s/releases?per_page=100"
local CLONE_URL = "https://gitcode.com/%s.git"
local NOTE = "OpenHarmony"
local RELEASES_ATTEMPTS = 3
local RETRY_DELAY = 10

local M = {}

function M.isOhosVersion(version)
    return type(version) == "string" and version:find(MARKER, 1, true) ~= nil
end

local function releases()
    local lastErr = "unknown error"
    for attempt = 1, RELEASES_ATTEMPTS do
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
        if attempt < RELEASES_ATTEMPTS then
            sleep(RETRY_DELAY)
        end
    end
    return nil, lastErr
end

function M.list()
    local result = {}
    for _, info in ipairs(releases() or {}) do
        local version = info.tag_name
        if M.isOhosVersion(version) then
            table.insert(result, {
                version = version,
                url = CLONE_URL:format(REPO),
                key = version,
                note = NOTE
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
    local body, err = releases()
    if body == nil then
        error("OpenHarmony releases are unavailable from " .. RELEASES_URL:format(REPO)
            .. ": " .. tostring(err))
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
        note = NOTE
    }
end

function M.clean(version)
    local dir = git.workDir(version)
    if dir ~= nil then
        git.removeDir(dir)
    end
end

return M
