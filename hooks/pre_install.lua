local http = require("http")
local json = require("json")

require("util")

function PLUGIN:PreInstall(ctx)
    local arg, requestedArch = splitVersionAndArch(ctx.version)
    local platform = getOsTypeAndArch()
    local targetArch = requestedArch or platform.archType
    local channelKey
    if arg == "beta" or arg == "dev" or arg == "stable" then
        local resp, err = http.get({
            url = BASE_URL:format(platform.osType)
        })
        if err ~= nil or resp.status_code ~= 200 then
            error("get version failed" .. err)
        end
        local body = json.decode(resp.body)
        channelKey = body.current_release[arg]
        if channelKey == nil then
            return nil
        end
    end

    local function package(info, version)
        return {
            -- Keep existing unqualified install/use commands and directory
            -- names. Explicit architecture requests get distinct versions.
            version = requestedArch and info.version or version,
            url = info.url,
            sha256 = info.sha256
        }
    end

    local legacy
    for _, info in ipairs(self:Available({})) do
        local version, arch = splitVersionAndArch(info.version)
        local matches = channelKey and info.key == channelKey or
            (channelKey == nil and version == arg)
        if matches then
            if arch == targetArch then
                return package(info, version)
            elseif arch == nil and requestedArch == nil then
                -- Older releases have no architecture metadata. Preserve their
                -- existing behavior only for requests without an architecture.
                legacy = package(info, version)
            end
        end
    end
    return legacy
end
