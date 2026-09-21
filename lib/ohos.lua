local http = require("http")
local json = require("json")

local MARKER = "-ohos-"
local REPO = "CPF-Flutter/flutter_flutter"
local RELEASES_URL = "https://gitcode.com/api/v5/repos/%s/releases?per_page=100"
local CLONE_URL = "https://gitcode.com/%s.git"
local NOTE = "OpenHarmony"
local HOME_ENV = "VFOX_HOME"
local FALLBACK_HOME_ENV = { "HOME", "USERPROFILE" }
local VFOX_DIR = ".vfox"
local TMP_DIR = "tmp"
local ENGINE_PIN = "bin/internal/engine.version"

local M = {}

function M.isOhosVersion(version)
    return type(version) == "string" and version:find(MARKER, 1, true) ~= nil
end

local function quote(value)
    if RUNTIME.osType == "windows" then
        return value
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function run(command)
    local result = os.execute(command)
    return result == 0 or result == true
end

local function git(root, args)
    return run("git -C " .. quote(root) .. " " .. args)
end

local function removeDir(path)
    if RUNTIME.osType == "windows" then
        os.execute('if exist "' .. path .. '" rmdir /s /q "' .. path .. '"')
    else
        os.execute("rm -rf " .. quote(path))
    end
end

local function sep()
    if RUNTIME.osType == "windows" then
        return "\\"
    end
    return "/"
end

local function localPath(path)
    local translated = path:gsub("/", sep())
    return translated
end

local function releases()
    local resp, err = http.get({ url = RELEASES_URL:format(REPO) })
    if err ~= nil or resp.status_code ~= 200 then
        return nil
    end
    local body = json.decode(resp.body)
    if type(body) ~= "table" then
        return nil
    end
    return body
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

local function vfoxHome()
    local home = os.getenv(HOME_ENV)
    if home == nil or home == "" then
        for _, name in ipairs(FALLBACK_HOME_ENV) do
            home = os.getenv(name)
            if home ~= nil and home ~= "" then
                break
            end
        end
    end
    if home == nil or home == "" then
        return nil
    end
    return localPath(home .. "/" .. VFOX_DIR)
end

local function workDir(version)
    local home = vfoxHome()
    if home == nil then
        return nil
    end
    return localPath(home .. "/" .. TMP_DIR .. "/" .. version)
end

local function parentDir(dir)
    return dir:match("^(.+)[" .. sep() .. "][^" .. sep() .. "]+$")
end

local function makeParentDir(dir)
    if RUNTIME.osType == "windows" then
        return
    end
    local parent = parentDir(dir)
    if parent == nil then
        return
    end
    os.execute("mkdir -p " .. quote(parent))
end

local function resetDir(dir)
    removeDir(dir)
    makeParentDir(dir)
end

function M.checkout(version, requestedArch)
    if requestedArch ~= nil then
        return nil
    end
    local commit
    for _, info in ipairs(releases() or {}) do
        if info.tag_name == version then
            commit = info.target_commitish
            break
        end
    end
    if commit == nil or commit == "" then
        return nil
    end
    local dir = workDir(version)
    if dir == nil then
        error("cannot resolve the vfox home directory")
    end
    local cloneUrl = CLONE_URL:format(REPO)
    resetDir(dir)
    if not run("git init -q " .. quote(dir)) then
        error("failed to initialize git in " .. dir .. " (is git installed?)")
    end
    if not git(dir, "fetch -q --depth 1 " .. cloneUrl .. " " .. commit) then
        error("failed to fetch " .. commit .. " from " .. cloneUrl)
    end
    if not git(dir, "checkout -q FETCH_HEAD") then
        error("failed to check out " .. commit .. " in " .. dir)
    end
    local pin = io.open(localPath(dir .. "/" .. ENGINE_PIN), "r")
    if pin == nil then
        error("the checkout at " .. commit .. " has no engine version pin")
    end
    pin:close()
    return {
        version = version,
        url = dir,
        note = NOTE
    }
end

function M.clean(version)
    local dir = workDir(version)
    if dir ~= nil then
        removeDir(dir)
    end
end

return M
