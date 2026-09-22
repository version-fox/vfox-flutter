local REPO = "flutter/flutter"
local CLONE_URL = "https://github.com/%s.git"
local HOME_ENV = "VFOX_HOME"
local FALLBACK_HOME_ENV = { "HOME", "USERPROFILE" }
local VFOX_DIR = ".vfox"
local TMP_DIR = "tmp"
local ENGINE_PIN = "bin/internal/engine.version"

local M = {}

function M.repoUrl()
    return CLONE_URL:format(REPO)
end

function M.supports(osType, archType)
    return osType == "linux" and archType == "arm64"
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
    local dir = workDir(versionName)
    if dir == nil then
        error("cannot resolve the vfox home directory")
    end
    local cloneUrl = M.repoUrl()
    resetDir(dir)
    if not run("git init -q " .. quote(dir)) then
        error("failed to initialize git in " .. dir .. " (is git installed?)")
    end
    if not git(dir, "fetch -q --depth 1 " .. cloneUrl .. " refs/tags/" .. baseVersion) then
        error("failed to fetch tag " .. baseVersion .. " from " .. cloneUrl)
    end
    if not git(dir, "checkout -q FETCH_HEAD") then
        error("failed to check out " .. baseVersion .. " in " .. dir)
    end
    local pin = io.open(localPath(dir .. "/" .. ENGINE_PIN), "r")
    if pin == nil then
        error("the checkout at " .. baseVersion .. " has no engine version pin")
    end
    pin:close()
    return {
        version = versionName,
        url = dir
    }
end

function M.clean(version)
    local dir = workDir(version)
    if dir ~= nil then
        removeDir(dir)
    end
end

return M
