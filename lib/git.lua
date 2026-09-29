local HOME_ENV = "VFOX_HOME"
local FALLBACK_HOME_ENV = { "HOME", "USERPROFILE" }
local VFOX_DIR = ".vfox"
local TMP_DIR = "tmp"
local ENGINE_PIN = "bin/internal/engine.version"
local FETCH_TIMEOUT = 10
local FETCH_ATTEMPTS = 3
local GH_PROXY_PREFIX = "https://gh-proxy.org/"
local GH_BASE = "https://github.com/"

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

local function isGithubUrl(url)
    return type(url) == "string" and url:sub(1, #GH_BASE) == GH_BASE
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

-- PowerShell -EncodedCommand needs UTF-16LE. The script is ASCII-only, so
-- interleaving NUL bytes is sufficient.
local function utf16le(data)
    return data:gsub("(.)", "%1" .. string.char(0))
end

-- Probe whether the remote answers within the timeout. Success means the
-- first byte arrived: once the transfer starts, the real fetch below runs
-- without a timeout and is never interrupted.
local function probeWithTimeoutUnix(remote, ref, timeout)
    local gitCmd = "git ls-remote --exit-code " .. quote(remote) .. " " .. quote(ref)
    -- Note: %%s becomes %s for the shell, %d is the Lua format arg for timeout
    local script = string.format(
        [[tmp=$(mktemp /tmp/vfox_probe_XXXXXX)
start=$(date +%%s)
end=$((start + %d))
%s >"$tmp" 2>/dev/null &
pid=$!
while kill -0 $pid 2>/dev/null; do
    if [ -s "$tmp" ]; then
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
        rm -f "$tmp"
        printf "\r%%*s\r" 40 ""
        printf "\n"
        exit 0
    fi
    now=$(date +%%s)
    remaining=$((end - now))
    if [ $remaining -le 0 ]; then
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
        rm -f "$tmp"
        printf "\r%%*s\r" 40 ""
        printf "\n"
        exit 124
    fi
    printf "\rTimeout in %%3ds... " $remaining
    sleep 1
done
wait $pid
rc=$?
rm -f "$tmp"
printf "\r%%*s\r" 40 ""
printf "\n"
exit $rc
]], timeout, gitCmd)
    return exec(script)
end

local function probeWithTimeoutWindows(remote, ref, timeout)
    -- The plugin runtime does not process shell quotes on Windows (a quoted
    -- -File path arrives literally and fails with "Illegal characters in
    -- path"), so the script is passed via -EncodedCommand instead: base64
    -- has no spaces or quotes and survives any argv splitting.
    local function psArg(value)
        return '"' .. value:gsub('"', '""') .. '"'
    end
    local script = string.format([[
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("vfox_probe_" + $PID + ".out")
$proc = Start-Process -FilePath "git" -ArgumentList @("ls-remote", "--exit-code", %s, %s) -RedirectStandardOutput $tmp -RedirectStandardError "NUL" -PassThru -NoNewWindow
$deadline = (Get-Date).AddSeconds(%d)
while (-not $proc.HasExited) {
    if ((Test-Path $tmp) -and ((Get-Item $tmp).Length -gt 0)) {
        try { $proc.Kill() } catch {}
        Remove-Item -Force $tmp
        Write-Host ""
        exit 0
    }
    $remaining = [int]($deadline - (Get-Date)).TotalSeconds
    if ($remaining -le 0) {
        try { $proc.Kill() } catch {}
        Remove-Item -Force $tmp -ErrorAction SilentlyContinue
        Write-Host ""
        exit 124
    }
    Write-Host -NoNewline ("`rTimeout in " + $remaining + " s... ")
    Start-Sleep -Seconds 1
}
Remove-Item -Force $tmp -ErrorAction SilentlyContinue
Write-Host ""
exit $proc.ExitCode
]], psArg(remote), psArg(ref), timeout)
    return exec("powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -EncodedCommand "
        .. base64(utf16le(script)))
end

local function probeWithTimeout(remote, ref, timeout)
    io.write(string.format("Connecting to %s (timeout: %ds)...\n", remote, timeout))
    io.flush()
    if RUNTIME.osType == "windows" then
        return probeWithTimeoutWindows(remote, ref, timeout)
    end
    return probeWithTimeoutUnix(remote, ref, timeout)
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
    if not exec("git init -q " .. quote(root)) then
        return false
    end
    return git(root, "config core.longpaths true")
end

local function fetchPlain(root, remote, ref)
    for _ = 1, FETCH_ATTEMPTS do
        if git(root, "fetch -q --depth 1 " .. remote .. " " .. ref) then
            return true
        end
    end
    return false
end

function M.fetch(root, remote, ref)
    if not isGithubUrl(remote) then
        return fetchPlain(root, remote, ref)
    end
    local remotes = { remote, GH_PROXY_PREFIX .. remote }
    for i, url in ipairs(remotes) do
        if probeWithTimeout(url, ref, FETCH_TIMEOUT) then
            if fetchPlain(root, url, ref) then
                return true
            end
        end
        if i < #remotes then
            io.write(string.format("Cannot reach %s, trying %s...\n", url, remotes[i + 1]))
            io.flush()
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
