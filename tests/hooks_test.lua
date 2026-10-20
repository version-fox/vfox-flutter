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

package.path = "./lib/?.lua;" .. package.path

local fixture, requests, mirror, sleeps
-- What gitcode.com answers, when a test wants it to answer anything but the fixture: a function
-- of the request that returns what http.get returns, and the releases that its 200 carries.
local gitcode, gitcodeReleases
local originalGetenv = os.getenv
os.getenv = function(name)
    if name == "FLUTTER_STORAGE_BASE_URL" then
        return mirror
    end
    return originalGetenv(name)
end
package.preload.http = function()
    return {
        get = function(request)
            table.insert(requests, request.url)
            if gitcode ~= nil and request.url:find("gitcode.com", 1, true) then
                return gitcode(request)
            end
            return { status_code = 200, body = "fixture" }, nil
        end,
    }
end
package.preload.json = function()
    return {
        decode = function(body)
            if body == "gitcode releases" then
                return gitcodeReleases
            end
            return fixture
        end,
    }
end

local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- Everything the plugin writes to stderr while fn runs.
local function captureStderr(fn)
    local written = {}
    local original = io.stderr
    rawset(io, "stderr", {
        write = function(_, text)
            table.insert(written, text)
            return true
        end,
    })
    local ok, err = pcall(fn)
    rawset(io, "stderr", original)
    assert(ok, err)
    return table.concat(written)
end

-- Runs fn with every shell command succeeding, and the engine version pin of a checkout present:
-- the checkout code of the plugin runs, git does not. Returns what fn returned and the commands.
local function withoutGit(fn)
    local execute, open = os.execute, io.open
    local commands = {}
    os.execute = function(command)
        table.insert(commands, command)
        return 0
    end
    rawset(io, "open", function(path, mode)
        if type(path) == "string" and path:find("engine.version", 1, true) then
            return { close = function() end }
        end
        return open(path, mode)
    end)
    local ok, result = pcall(fn)
    os.execute = execute
    rawset(io, "open", open)
    assert(ok, result)
    return result, commands
end

local function release(version, arch, channel, hash)
    return {
        version = version,
        dart_sdk_arch = arch,
        channel = channel,
        hash = hash,
        archive = "sdk/" .. version .. "-" .. (arch or "legacy") .. ".zip",
        sha256 = version .. ":" .. (arch or "legacy"),
        dart_sdk_version = "3.12.0",
    }
end

local function setup(osType, archType, storage)
    mirror, requests, sleeps = storage, {}, {}
    gitcode, gitcodeReleases = nil, nil
    RUNTIME = { osType = osType, archType = archType }
    -- Both architectures share the same Flutter commit. Put x64 first to catch
    -- channel selection that relies on the upstream array's order.
    fixture = {
        current_release = { stable = "stable", beta = "beta", dev = "dev" },
        base_url = "https://upstream.example/releases",
        releases = {
            release("3.44.0", "x64", "stable", "stable"),
            release("3.44.0", "arm64", "stable", "stable"),
            release("3.44.0-0.1.pre", "x64", "beta", "beta"),
            release("3.44.0-0.1.pre", "arm64", "beta", "beta"),
            release("3.43.0-0.1.pre", "x64", "dev", "dev"),
            release("3.43.0-0.1.pre", "arm64", "dev", "dev"),
            release("2.10.0", nil, "stable", "legacy"),
        },
    }
    package.loaded.util = nil
    dofile("metadata.lua")
    dofile("hooks/available.lua")
    dofile("hooks/pre_install.lua")
    -- util.lua defines sleep: replace it once it is loaded, and record instead of waiting.
    sleep = function(seconds)
        table.insert(sleeps, seconds)
    end
end

local function installed(request, version, arch)
    local result = PLUGIN:PreInstall({ version = request })
    assert(result, "no package selected for " .. request)
    equal(result.version, version)
    assert(result.url:find("-" .. arch .. ".zip", 1, true), result.url)
    assert(result.sha256:find(":" .. arch, 1, true), result.sha256)
    return result
end

local tests = {}
tests[#tests + 1] = {
    "all variants are listed with native architecture first",
    function()
        for _, arch in ipairs({ "arm64", "amd64" }) do
            setup("darwin", arch)
            local versions = PLUGIN:Available({})
            equal(#versions, 7)
            equal(versions[1].version, "3.44.0-" .. (arch == "amd64" and "x64" or arch))
            local found = {}
            for _, version in ipairs(versions) do
                found[version.version] = true
            end
            assert(found["3.44.0-x64"] and found["3.44.0-arm64"] and found["2.10.0"])
            equal(versions[1].addition[1].version, "3.12.0")
        end
    end,
}
tests[#tests + 1] = {
    "explicit architectures select matching archives",
    function()
        setup("darwin", "arm64")
        installed("3.44.0-x64", "3.44.0-x64", "x64")
        installed("3.44.0-arm64", "3.44.0-arm64", "arm64")
    end,
}
tests[#tests + 1] = {
    "latest keeps the default architecture when a foreign build is newer",
    function()
        setup("darwin", "arm64")
        table.insert(fixture.releases, 1, release("3.45.0", "x64", "beta", "newer"))
        local versions = PLUGIN:Available({})
        equal(versions[1].version, "3.44.0-arm64")
        installed(versions[1].version, "3.44.0-arm64", "arm64")
    end,
}
tests[#tests + 1] = {
    "existing version commands retain native selection and version names",
    function()
        for _, platform in ipairs({ "darwin", "linux", "windows" }) do
            for _, arch in ipairs({ "arm64", "amd64" }) do
                setup(platform, arch)
                installed("3.44.0", "3.44.0", arch == "amd64" and "x64" or arch)
            end
        end
    end,
}
tests[#tests + 1] = {
    "channels use the native architecture even when hashes are shared",
    function()
        for _, arch in ipairs({ "arm64", "amd64" }) do
            setup("darwin", arch)
            for channel, version in pairs({ stable = "3.44.0", beta = "3.44.0-0.1.pre" }) do
                installed(channel, version, arch == "amd64" and "x64" or arch)
                installed(channel .. "-x64", version .. "-x64", "x64")
                installed(channel .. "-arm64", version .. "-arm64", "arm64")
            end
        end
    end,
}
tests[#tests + 1] = {
    "the retired dev channel is not resolved",
    function()
        setup("darwin", "arm64")
        equal(PLUGIN:PreInstall({ version = "dev" }), nil)
        equal(PLUGIN:PreInstall({ version = "dev-x64" }), nil)
    end,
}
tests[#tests + 1] = {
    "pre-release versions retain their full version strings",
    function()
        setup("darwin", "arm64")
        installed("3.44.0-0.1.pre", "3.44.0-0.1.pre", "arm64")
        installed("3.44.0-0.1.pre-x64", "3.44.0-0.1.pre-x64", "x64")
    end,
}
tests[#tests + 1] = {
    "architecture suffixes do not change version ordering",
    function()
        setup("darwin", "arm64")
        equal(compare_versions("3.44.0-arm64", "3.44.0-x64"), 0)
        equal(compare_versions("3.44.0", "3.44.0-arm64"), 0)
        assert(compare_versions("3.44.0-arm64", "3.44.0-0.1.pre-x64") > 0)
        assert(compare_versions("3.44.0-0.2.pre-x64", "3.44.0-0.1.pre-arm64") > 0)
    end,
}
tests[#tests + 1] = {
    "mirror is used for index and every architecture's archive",
    function()
        setup("darwin", "arm64", "https://mirror.example/flutter/")
        local result = installed("3.44.0-x64", "3.44.0-x64", "x64")
        equal(requests[1], "https://mirror.example/flutter/flutter_infra_release/releases/releases_macos.json")
        equal(result.url, "https://mirror.example/flutter/flutter_infra_release/releases/sdk/3.44.0-x64.zip")
    end,
}
tests[#tests + 1] = {
    "legacy releases remain installable without inventing architecture variants",
    function()
        setup("darwin", "arm64")
        installed("2.10.0", "2.10.0", "legacy")
        equal(PLUGIN:PreInstall({ version = "2.10.0-arm64" }), nil)
    end,
}
tests[#tests + 1] = {
    "missing architecture never falls back to an incompatible archive",
    function()
        setup("darwin", "arm64")
        fixture.releases = { release("3.44.0", "x64", "stable", "stable") }
        equal(PLUGIN:PreInstall({ version = "3.44.0" }), nil)
        equal(PLUGIN:PreInstall({ version = "stable" }), nil)
        equal(PLUGIN:PreInstall({ version = "stable-arm64" }), nil)
        installed("stable-x64", "3.44.0-x64", "x64")
    end,
}
tests[#tests + 1] = {
    "fetch gives up on a stalled transfer and retries",
    function()
        RUNTIME = { osType = "linux", archType = "amd64" }
        local git = require("git")
        local commands, exits = {}, { 1, 1, 0, 1, 1, 1 }
        local execute = os.execute
        os.execute = function(command)
            table.insert(commands, command)
            return table.remove(exits, 1)
        end
        local first = git.fetch("/sdk", "https://example.invalid/flutter.git", "refs/tags/3.44.0")
        local second = git.fetch("/sdk", "https://example.invalid/flutter.git", "refs/tags/3.44.0")
        os.execute = execute
        equal(first, true)
        equal(second, false)
        equal(#commands, 6)
        local guard = "git -C '/sdk' -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=60 fetch "
        assert(commands[1]:find(guard, 1, true), commands[1])
    end,
}
tests[#tests + 1] = {
    "installing an official release never asks gitcode.com",
    function()
        setup("linux", "amd64")
        installed("3.44.0", "3.44.0", "x64")
        installed("stable", "3.44.0", "x64")
        installed("3.44.0-0.1.pre-x64", "3.44.0-0.1.pre-x64", "x64")
        for _, url in ipairs(requests) do
            assert(not url:find("gitcode.com", 1, true), "asked " .. url)
        end
        -- `vfox search`, and the `latest` of `vfox install`, list the OpenHarmony releases too
        requests = {}
        PLUGIN:Available({})
        local asked = 0
        for _, url in ipairs(requests) do
            if url:find("gitcode.com", 1, true) then
                asked = asked + 1
            end
        end
        equal(asked, 1)
    end,
}
tests[#tests + 1] = {
    "a rate-limited gitcode.com costs a listing no wait, and the listing says what is missing",
    function()
        setup("linux", "amd64")
        gitcode = function()
            return { status_code = 429, body = "limited" }, nil
        end
        local versions
        local warning = captureStderr(function()
            versions = PLUGIN:Available({})
        end)
        equal(#versions, 7)
        equal(#sleeps, 0)
        assert(warning:find("OpenHarmony releases could not be read from gitcode.com (HTTP 429)", 1, true), warning)
        assert(warning:find("only the official releases are listed", 1, true), warning)
    end,
}
tests[#tests + 1] = {
    "a listing tries a failed gitcode.com request once more",
    function()
        setup("linux", "amd64")
        local calls = 0
        gitcode = function()
            calls = calls + 1
            return nil, "connection refused"
        end
        local warning = captureStderr(function()
            PLUGIN:Available({})
        end)
        equal(calls, 2)
        equal(tostring(table.concat(sleeps, ",")), "2")
        assert(warning:find("connection refused", 1, true), warning)
    end,
}
tests[#tests + 1] = {
    "installing an OpenHarmony build waits out a rate-limited gitcode.com",
    function()
        setup("linux", "amd64")
        gitcodeReleases = { { tag_name = "3.41.10-ohos-1.0.0", target_commitish = "abc123" } }
        local calls = 0
        gitcode = function()
            calls = calls + 1
            if calls <= 4 then
                return { status_code = 429, body = "limited" }, nil
            end
            return { status_code = 200, body = "gitcode releases" }, nil
        end
        local result, commands = withoutGit(function()
            return PLUGIN:PreInstall({ version = "3.41.10-ohos-1.0.0" })
        end)
        equal(result.version, "3.41.10-ohos-1.0.0")
        equal(calls, 5)
        equal(table.concat(sleeps, ","), "30,60,120,180")
        local fetch = "fetch -q --depth 1 https://gitcode.com/CPF-Flutter/flutter_flutter.git abc123"
        local fetched = false
        for _, command in ipairs(commands) do
            fetched = fetched or command:find(fetch, 1, true) ~= nil
        end
        assert(fetched, "the commit was not fetched")
    end,
}
tests[#tests + 1] = {
    "OpenHarmony releases tagged with +ohos- are listed and installable",
    function()
        setup("linux", "amd64")
        gitcodeReleases = {
            { tag_name = "3.41.10-ohos-1.0.0", target_commitish = "aaa111" },
            { tag_name = "3.41.9+ohos-1.0.2", target_commitish = "bbb222" },
            { tag_name = "v0.0.1", target_commitish = "ccc333" },
        }
        gitcode = function()
            return { status_code = 200, body = "gitcode releases" }, nil
        end
        local names = {}
        for _, info in ipairs(PLUGIN:Available({})) do
            table.insert(names, info.version)
        end
        -- after the seven official releases, newest first, and without the tag that is neither
        equal(#names, 9)
        equal(names[8], "3.41.10-ohos-1.0.0")
        equal(names[9], "3.41.9+ohos-1.0.2")
        local result, commands = withoutGit(function()
            return PLUGIN:PreInstall({ version = "3.41.9+ohos-1.0.2" })
        end)
        equal(result.version, "3.41.9+ohos-1.0.2")
        local fetched = false
        for _, command in ipairs(commands) do
            fetched = fetched or command:find(" bbb222", 1, true) ~= nil
        end
        assert(fetched, "the commit was not fetched")
        local ok, err = pcall(PLUGIN.PreInstall, PLUGIN, { version = "3.41.9+ohos-1.0.2-x64" })
        assert(not ok and tostring(err):find("has no architecture variants", 1, true), tostring(err))
    end,
}
tests[#tests + 1] = {
    "stable releases come before pre-releases, so latest is the newest stable release",
    function()
        for _, arch in ipairs({ "arm64", "amd64" }) do
            local native = arch == "amd64" and "x64" or arch
            setup("darwin", arch)
            table.insert(fixture.releases, 1, release("3.45.0-0.1.pre", "x64", "beta", "newer"))
            table.insert(fixture.releases, 2, release("3.45.0-0.1.pre", "arm64", "beta", "newer"))
            local versions = PLUGIN:Available({})
            equal(versions[1].version, "3.44.0-" .. native)
            -- of the native architecture, every stable release is before every pre-release
            local pre = false
            for _, info in ipairs(versions) do
                local _, infoArch = splitVersionAndArch(info.version)
                if infoArch == nil or infoArch == native then
                    if info.note == "stable" then
                        assert(not pre, info.version .. " is listed after a pre-release")
                    else
                        pre = true
                    end
                end
            end
            assert(pre, "no pre-release was listed")
            -- and a pre-release still installs by its name
            installed("3.45.0-0.1.pre", "3.45.0-0.1.pre", native)
        end
    end,
}
tests[#tests + 1] = {
    "an archive published again keeps the entry with the newest checksum",
    function()
        local old = release("3.43.1", "x64", "stable", "oldcommit")
        old.release_date, old.sha256 = "2026-01-01T10:00:00Z", "old:x64"
        local new = release("3.43.1", "x64", "stable", "newcommit")
        new.release_date, new.sha256 = "2026-01-01T12:00:00Z", "new:x64"
        -- whichever comes first in the index
        for _, entries in ipairs({ { old, new }, { new, old } }) do
            setup("linux", "amd64")
            for _, entry in ipairs(entries) do
                table.insert(fixture.releases, entry)
            end
            local listed = 0
            for _, info in ipairs(PLUGIN:Available({})) do
                if info.version == "3.43.1-x64" then
                    listed = listed + 1
                    equal(info.sha256, "new:x64")
                end
            end
            equal(listed, 1)
            equal(PLUGIN:PreInstall({ version = "3.43.1" }).sha256, "new:x64")
        end
        -- a release promoted to another channel has an archive in each, and keeps both entries
        setup("linux", "amd64")
        local beta = release("3.42.0-0.1.pre", "x64", "beta", "promoted")
        local dev = release("3.42.0-0.1.pre", "x64", "dev", "promoted")
        dev.archive, dev.sha256 = "sdk/dev/3.42.0-0.1.pre-x64.zip", "dev:x64"
        table.insert(fixture.releases, dev)
        table.insert(fixture.releases, beta)
        local notes = {}
        for _, info in ipairs(PLUGIN:Available({})) do
            if info.version == "3.42.0-0.1.pre-x64" then
                table.insert(notes, info.note)
            end
        end
        equal(table.concat(notes, ","), "beta,dev")
        -- different versions never merge, even when a mirror gives them one archive
        setup("linux", "amd64")
        local first = release("3.42.5", "x64", "stable", "first")
        local second = release("3.42.6", "x64", "stable", "second")
        second.archive = first.archive
        table.insert(fixture.releases, first)
        table.insert(fixture.releases, second)
        local found = {}
        for _, info in ipairs(PLUGIN:Available({})) do
            found[info.version] = true
        end
        assert(found["3.42.5-x64"] and found["3.42.6-x64"], "versions that share an archive were merged")
    end,
}
tests[#tests + 1] = {
    "ARM64 source installs start at the first release that runs with a native Dart SDK",
    function()
        local function names()
            local found = {}
            for _, info in ipairs(PLUGIN:Available({})) do
                found[info.version] = true
            end
            return found
        end
        setup("linux", "arm64")
        fixture.releases = {
            release("3.44.0", "x64", "stable", "c3"),
            release("2.2.0", "x64", "stable", "c2"),
            release("2.0.6", "x64", "stable", "c1"),
        }
        local linux = names()
        assert(linux["3.44.0-arm64"] and linux["2.2.0-arm64"], "native releases are not offered")
        assert(not linux["2.0.6-arm64"], "the tool of 2.0.6 takes the x64 Dart SDK on Linux")
        assert(linux["2.0.6-x64"], "the x64 archive is still listed")
        equal(PLUGIN:PreInstall({ version = "2.0.6" }), nil)
        equal(PLUGIN:PreInstall({ version = "2.0.6-arm64" }), nil)
        installed("2.0.6-x64", "2.0.6-x64", "x64")
        setup("windows", "arm64")
        fixture.releases = {
            release("3.44.0", "x64", "stable", "c4"),
            release("3.44.0-0.1.pre", "x64", "beta", "c3"),
            release("3.43.0-0.3.pre", "x64", "beta", "c2"),
            release("3.11.0-0.0.pre", "x64", "beta", "c1"),
        }
        local windows = names()
        assert(windows["3.44.0-arm64"] and windows["3.44.0-0.1.pre-arm64"], "native releases are not offered")
        assert(not windows["3.43.0-0.3.pre-arm64"], "3.43.0-0.3.pre falls back to the x64 Dart SDK on Windows")
        assert(not windows["3.11.0-0.0.pre-arm64"], "older betas are left out")
        assert(windows["3.43.0-0.3.pre-x64"], "the x64 archive is still listed")
    end,
}
tests[#tests + 1] = {
    "git checkouts ignore core.autocrlf in your git configuration",
    function()
        local function succeeded(status)
            return status == 0 or status == true
        end
        local execute = os.execute
        if originalGetenv("OS") == "Windows_NT" or not succeeded(execute("git --version >/dev/null 2>&1")) then
            print("SKIP git checkouts ignore core.autocrlf: needs git and a POSIX shell")
            return
        end
        RUNTIME = { osType = "linux", archType = "amd64" }
        local git = require("git")
        local base = os.tmpname()
        os.remove(base)
        local origin, plain, checkout, config =
            base .. "/origin", base .. "/plain", base .. "/checkout", base .. "/config"
        -- as a user whose git configuration says core.autocrlf=true
        local function asUser(command)
            return execute("GIT_CONFIG_GLOBAL='" .. config .. "' GIT_CONFIG_NOSYSTEM=1 " .. command)
        end
        local function write(path, text)
            local file = assert(io.open(path, "wb"))
            file:write(text)
            file:close()
        end
        local function read(path)
            local file = assert(io.open(path, "rb"))
            local text = file:read("*a")
            file:close()
            return text
        end
        assert(succeeded(execute("mkdir -p '" .. origin .. "'")))
        write(config, "[core]\n\tautocrlf = true\n")
        write(origin .. "/.gitattributes", "*.sh text\n")
        write(origin .. "/run.sh", "echo hi\n")
        assert(succeeded(asUser("git init -q '" .. origin .. "'")))
        local commit = "git -C '" .. origin .. "' -c core.autocrlf=false -c user.name=t -c user.email=t@t "
        assert(succeeded(asUser(commit .. "add .")))
        assert(succeeded(asUser(commit .. "commit -q -m c")))
        assert(succeeded(asUser(commit .. "tag t1")))
        -- the control: with that configuration a plain checkout has CRLF line endings
        local fetch = " fetch -q --depth 1 file://" .. origin .. " refs/tags/t1"
        assert(succeeded(asUser("git init -q '" .. plain .. "'")))
        assert(succeeded(asUser("git -C '" .. plain .. "'" .. fetch)))
        assert(succeeded(asUser("git -C '" .. plain .. "' checkout -q FETCH_HEAD")))
        assert(read(plain .. "/run.sh"):find("\r", 1, true), "the control checkout has no CRLF")
        -- the plugin's checkout does not
        rawset(os, "execute", function(command)
            return asUser(command)
        end)
        local ok, err = pcall(function()
            assert(git.init(checkout), "git init failed")
            assert(git.fetch(checkout, "file://" .. origin, "refs/tags/t1"), "git fetch failed")
            assert(git.checkoutHead(checkout), "git checkout failed")
        end)
        rawset(os, "execute", execute)
        local text = ok and read(checkout .. "/run.sh") or ""
        execute("rm -rf '" .. base .. "'")
        assert(ok, err)
        assert(not text:find("\r", 1, true), "the checkout has CRLF line endings")
        equal(text, "echo hi\n")
    end,
}
tests[#tests + 1] = {
    "an unsupported CPU is named in the message",
    function()
        setup("linux", "amd64")
        for _, cpu in ipairs({ "386", "arm", "riscv64" }) do
            RUNTIME = { osType = "linux", archType = cpu }
            local ok, err = pcall(getOsTypeAndArch)
            assert(
                not ok and tostring(err):find("flutter does not support the " .. cpu .. " architecture", 1, true),
                tostring(err)
            )
        end
    end,
}

local failures = 0
for _, test in ipairs(tests) do
    local ok, err = pcall(test[2])
    if ok then
        print("PASS " .. test[1])
    else
        failures = failures + 1
        print("FAIL " .. test[1] .. ": " .. tostring(err))
    end
end
assert(failures == 0, tostring(failures) .. " test groups failed")
