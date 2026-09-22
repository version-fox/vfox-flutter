local HOME_ENV = "VFOX_HOME"
local FALLBACK_HOME_ENV = { "HOME", "USERPROFILE" }
local VFOX_DIR = ".vfox"
local TMP_DIR = "tmp"
local ENGINE_PIN = "bin/internal/engine.version"
local FETCH_ATTEMPTS = 3

local M = {}

local function quote(value)
    if RUNTIME.osType == "windows" then
        return value
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function exec(command)
    local result = os.execute(command)
    return result == 0 or result == true
end

local function git(root, args)
    return exec("git -C " .. quote(root) .. " " .. args)
end

local function sep()
    if RUNTIME.osType == "windows" then
        return "\\"
    end
    return "/"
end

local function localPath(path)
    return path:gsub("/", sep())
end

function M.removeDir(path)
    if RUNTIME.osType == "windows" then
        exec('if exist "' .. path .. '" rmdir /s /q "' .. path .. '"')
    else
        exec("rm -rf " .. quote(path))
    end
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

function M.workDir(version)
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
    exec("mkdir -p " .. quote(parent))
end

function M.resetDir(dir)
    M.removeDir(dir)
    makeParentDir(dir)
end

function M.init(root)
    return exec("git init -q " .. quote(root))
end

function M.fetch(root, remote, ref)
    for _ = 1, FETCH_ATTEMPTS do
        if git(root, "fetch -q --depth 1 " .. remote .. " " .. ref) then
            return true
        end
    end
    return false
end

function M.checkoutHead(root)
    return git(root, "checkout -q FETCH_HEAD")
end

function M.hasEnginePin(root)
    local pin = io.open(localPath(root .. "/" .. ENGINE_PIN), "r")
    if pin == nil then
        return false
    end
    pin:close()
    return true
end

return M
