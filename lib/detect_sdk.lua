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

-- Find Flutter SDKs that are already on this machine for `vfox link --detect`.
-- A candidate is a directory whose `bin` holds `flutter` (or `flutter.bat`)
-- and whose root `version` file names the release. Google ships a full `.git`
-- checkout in every release archive no matter who downloads it, so the same
-- directories work no matter which manager put them there. Only fixed,
-- well-known locations are scanned; anything elsewhere is for
-- `vfox link flutter@<name> <path>`.
--
-- NOTE: this file is not called `detect.lua`: vfox searches `hooks/` before
-- `lib/`, so `require("detect")` would load `hooks/detect.lua` instead and
-- loop.
local M = {}

local function sep()
    if RUNTIME.osType == "windows" then
        return "\\"
    end
    return "/"
end

local function p(...)
    return table.concat({ ... }, sep())
end

-- Quote a path for the platform shell, the same rule as `lib/git.lua` and
-- `lib/manifest.lua`: double quotes around a path with whitespace on Windows
-- (vfox 1.0.13 and later pass it through verbatim), single quotes elsewhere.
local function quote(value)
    if RUNTIME.osType == "windows" then
        if value:find("%s") then
            return '"' .. value .. '"'
        end
        return value
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function trim(s)
    if type(s) ~= "string" then
        return nil
    end
    local t = s:match("^(.-)%s*$")
    if t == "" then
        return nil
    end
    return t
end

local function readable(path)
    local f = io.open(path, "rb")
    if f == nil then
        return false
    end
    f:close()
    return true
end

local function readTrimmed(path)
    local f = io.open(path, "rb")
    if f == nil then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return trim(content)
end

-- Names vfox accepts for a linked version: the same rule as core's
-- ValidVersionName (letters, digits, `.`, `_`, `+` and `-`, never `latest`).
function M.validName(name)
    if type(name) ~= "string" or name == "" or name == "latest" then
        return false
    end
    return name:match("^[A-Za-z0-9][A-Za-z0-9._%+%-]*$") ~= nil
end

local function isSdkDir(dir)
    if type(dir) ~= "string" or dir == "" then
        return false
    end
    local bin = p(dir, "bin")
    return readable(p(bin, "flutter")) or readable(p(bin, "flutter.bat"))
end

-- The release name from the SDK's own `version` file, or nil when it is
-- missing or not a name vfox could link under.
local function sdkVersion(dir)
    local v = readTrimmed(p(dir, "version"))
    if v ~= nil and M.validName(v) then
        return v
    end
    return nil
end

-- Immediate children of dir, sorted. Listing runs a process (`ls` on POSIX,
-- `dir` on Windows); Detect only runs for `vfox link --detect`, never on
-- `vfox use`, so that is fine here (unlike the Fingerprint hook, which must
-- stay under 50 ms and only reads files). A missing directory lists as
-- nothing, never as an error.
local function listNames(dir)
    if type(dir) ~= "string" or dir == "" then
        return {}
    end
    local cmd
    if RUNTIME.osType == "windows" then
        cmd = "dir /b /ad " .. quote(dir)
    else
        cmd = "ls -1 " .. quote(dir)
    end
    local ok, pipe = pcall(io.popen, cmd)
    if not ok or pipe == nil then
        return {}
    end
    local okRead, content = pcall(function()
        return pipe:read("*a")
    end)
    pcall(function()
        pipe:close()
    end)
    if not okRead or type(content) ~= "string" then
        return {}
    end
    local names = {}
    for line in (content .. "\n"):gmatch("(.-)\n") do
        local name = trim(line)
        if name ~= nil then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

local function homes()
    local out, seen = {}, {}
    for _, v in ipairs({ os.getenv("HOME"), os.getenv("USERPROFILE") }) do
        if type(v) == "string" and v ~= "" and not seen[v] then
            seen[v] = true
            table.insert(out, v)
        end
    end
    return out
end

local function envDir(name)
    local v = os.getenv(name)
    if type(v) == "string" and v ~= "" then
        return v
    end
    return nil
end

local function probe(dir, label, out, seen)
    if type(dir) ~= "string" or dir == "" or seen[dir] then
        return
    end
    seen[dir] = true
    if not isSdkDir(dir) then
        return
    end
    local version = sdkVersion(dir)
    if version == nil then
        return
    end
    table.insert(out, { version = version, path = dir, note = label })
end

-- Where to look, in order. `multi` roots hold one SDK per sub directory
-- (optionally one level deeper via `sub`, like Homebrew's `<ver>/flutter`);
-- `single` entries are probed as SDKs themselves.
local function roots()
    local list = {}
    local function addMulti(path, sub, label)
        table.insert(list, { multi = true, path = path, sub = sub, label = label })
    end
    local function addSingle(path, label)
        table.insert(list, { multi = false, path = path, label = label })
    end
    local hs = homes()
    if RUNTIME.osType == "darwin" then
        -- Homebrew keeps one directory per release, with the SDK inside it.
        addMulti("/opt/homebrew/Caskroom/flutter", "flutter", "Homebrew")
        addMulti("/usr/local/Caskroom/flutter", "flutter", "Homebrew")
    end
    -- mise and asdf keep one directory per installed version.
    local mise = envDir("MISE_DATA_DIR")
    if mise ~= nil then
        addMulti(p(mise, "installs", "flutter"), nil, "mise")
    end
    local asdf = envDir("ASDF_DATA_DIR")
    if asdf ~= nil then
        addMulti(p(asdf, "installs", "flutter"), nil, "asdf")
    end
    for _, h in ipairs(hs) do
        addMulti(p(h, ".local", "share", "mise", "installs", "flutter"), nil, "mise")
        addMulti(p(h, ".asdf", "installs", "flutter"), nil, "asdf")
        addMulti(p(h, "fvm", "versions"), nil, "FVM")
    end
    if RUNTIME.osType == "windows" then
        -- C:\src\flutter is the path Flutter's own install guide uses.
        addSingle("C:\\src\\flutter", "manual install")
        for _, h in ipairs(hs) do
            addSingle(p(h, "flutter"), "manual install")
            addSingle(p(h, "scoop", "apps", "flutter", "current"), "Scoop")
        end
    else
        for _, h in ipairs(hs) do
            addSingle(p(h, "development", "flutter"), "manual install")
            addSingle(p(h, "develop", "flutter"), "manual install")
            addSingle(p(h, "flutter"), "manual install")
        end
        addSingle("/opt/flutter", "manual install")
        addSingle("/usr/local/flutter", "manual install")
    end
    return list
end

-- Every Flutter SDK on this machine that lives in a well-known place, as
-- `{ version, path, note }` entries for `vfox link --detect`. vfox itself
-- skips what is already installed or linked. Nil when there is nothing.
function M.find()
    local out, seen = {}, {}
    for _, root in ipairs(roots()) do
        if root.multi then
            for _, name in ipairs(listNames(root.path)) do
                local cand = p(root.path, name)
                if root.sub ~= nil then
                    cand = p(cand, root.sub)
                end
                probe(cand, root.label, out, seen)
            end
        else
            probe(root.path, root.label, out, seen)
        end
    end
    if #out == 0 then
        return nil
    end
    return out
end

return M
