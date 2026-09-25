local json = require("json")

local MARKER = ".vfox-manifest"

local function sep()
    if RUNTIME.osType == "windows" then
        return "\\"
    end
    return "/"
end

local function joinPath(a, b)
    return a .. sep() .. b
end

-- vfox feeds command strings to cmd.exe /c on Windows. Go has to re-quote the
-- whole command line, which turns a double quote into \" so cmd.exe reads a
-- quoted path back as the volume-relative path \path\ and rejects it with
-- "The filename, directory name, or volume label syntax is incorrect." Match
-- lib/git.lua and pass paths unquoted there; a path with a space then simply
-- skips the drift check instead of breaking vfox use.
local function quote(value)
    if RUNTIME.osType == "windows" then
        return value
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function capture(command)
    local function run()
        local pipe = io.popen(command)
        if pipe == nil then
            return nil
        end
        local content = pipe:read("*a")
        pipe:close()
        if content == nil then
            return nil
        end
        content = content:match("^(.-)%s*$")
        if content == "" then
            return nil
        end
        return content
    end
    local ok, content = pcall(run)
    if not ok then
        return nil
    end
    return content
end

local function hasGitDir(path)
    local f = io.open(joinPath(path, ".git" .. sep() .. "HEAD"), "r")
    if f == nil then
        return false
    end
    f:close()
    return true
end

local function isEmptyTable(table)
    for _ in pairs(table) do
        return false
    end
    return true
end

local M = {}

function M.gitRoot(sdkRoot)
    if type(sdkRoot) ~= "string" or sdkRoot == "" then
        return nil
    end
    if hasGitDir(sdkRoot) then
        return sdkRoot
    end
    local listCmd
    if RUNTIME.osType == "windows" then
        listCmd = "dir /b /ad " .. quote(sdkRoot)
    else
        listCmd = "find " .. quote(sdkRoot) .. " -maxdepth 1 -mindepth 1 -type d -printf '%f\\n'"
    end
    local subdirs = capture(listCmd)
    if subdirs == nil then
        return nil
    end
    for line in (subdirs .. "\n"):gmatch("(.-)\n") do
        line = line:match("^(.-)%s*$")
        if line and line ~= "" then
            local candidate = joinPath(sdkRoot, line)
            if hasGitDir(candidate) then
                return candidate
            end
        end
    end
    return nil
end

function M.currentHead(sdkRoot)
    local root = M.gitRoot(sdkRoot)
    if root == nil then
        return nil
    end
    return capture("git -C " .. quote(root) .. " rev-parse HEAD")
end

function M.manifestPath(sdkRoot)
    local root = M.gitRoot(sdkRoot)
    if root == nil then
        return nil
    end
    return joinPath(root, MARKER)
end

function M.write(sdkRoot, info)
    local root = M.gitRoot(sdkRoot)
    if root == nil then
        return false
    end
    local head = capture("git -C " .. quote(root) .. " rev-parse HEAD")
    local data = {
        plugin = "vfox-flutter",
        plugin_version = (PLUGIN and PLUGIN.version) or "unknown",
        version = (info and info.version) or "unknown",
        expected_head = head,
        installed_at = os.time(),
    }
    local f = io.open(joinPath(root, MARKER), "w")
    if f == nil then
        return false
    end
    local ok, encoded = pcall(json.encode, data)
    if not ok then
        f:close()
        return false
    end
    f:write(encoded)
    f:close()
    return true
end

function M.read(sdkRoot)
    local path = M.manifestPath(sdkRoot)
    if path == nil then
        return nil
    end
    local f = io.open(path, "r")
    if f == nil then
        return nil
    end
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(json.decode, content)
    if not ok or type(data) ~= "table" or isEmptyTable(data) then
        return nil
    end
    return data
end

function M.checkDrift(sdkRoot)
    if type(sdkRoot) ~= "string" or sdkRoot == "" then
        return false, "no-path"
    end
    local m = M.read(sdkRoot)
    if m == nil then
        return false, "no-manifest"
    end
    if m.expected_head == nil or m.expected_head == "" then
        return false, "no-git-anchor"
    end
    local current = M.currentHead(sdkRoot)
    if current == nil then
        return true, "sdk-no-longer-git"
    end
    if current ~= m.expected_head then
        return true, "head-drifted"
    end
    return false, "ok"
end

return M
