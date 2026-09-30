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

local B64CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64(data)
    local out = {}
    for i = 1, #data, 3 do
        local a = data:byte(i)
        local b = data:byte(i + 1) or 0
        local c = data:byte(i + 2) or 0
        local n = a * 65536 + b * 256 + c
        out[#out + 1] = B64CHARS:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
            .. B64CHARS:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        if i + 1 > #data then
            out[#out + 1] = "=="
        elseif i + 2 > #data then
            out[#out + 1] = B64CHARS:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) .. "="
        else
            out[#out + 1] = B64CHARS:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1)
                .. B64CHARS:sub(n % 64 + 1, n % 64 + 1)
        end
    end
    return table.concat(out)
end

local function utf16le(data)
    return data:gsub("(.)", "%1" .. string.char(0))
end

-- PowerShell single-quoted strings are literal: 'text' escapes ' as ''.
local function psQuote(value)
    return "'" .. value:gsub("'", "''") .. "'"
end

-- Shell single-quote quoting. On Windows, capture wraps commands in PowerShell
-- with psQuote instead; this function is for Unix only.
local function quote(value)
    if RUNTIME.osType == "windows" then
        return value
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function capture(command)
    local function run()
        local shellCmd = command
        if RUNTIME.osType == "windows" then
            shellCmd = "powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -EncodedCommand "
                .. base64(utf16le(command))
        end
        local pipe = io.popen(shellCmd)
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
        listCmd = "Get-ChildItem -Directory " .. psQuote(sdkRoot) .. " | Select-Object -ExpandProperty Name"
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

local function gitRevParse(root)
    if RUNTIME.osType == "windows" then
        return capture("& git -C " .. psQuote(root) .. " rev-parse HEAD")
    end
    return capture("git -C " .. quote(root) .. " rev-parse HEAD")
end

function M.currentHead(sdkRoot)
    local root = M.gitRoot(sdkRoot)
    if root == nil then
        return nil
    end
    return gitRevParse(root)
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
    local head = gitRevParse(root)
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
