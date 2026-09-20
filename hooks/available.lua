local http = require("http")
local json = require("json")
local ohos = require("ohos")

require("util")
function PLUGIN:Available(ctx)
    local type = getOsTypeAndArch()
    local resp, err = http.get({
        url = BASE_URL:format(type.osType)
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("get version failed" .. err)
    end
    local body = json.decode(resp.body)
    local result = {}
    for _, info in ipairs(body.releases) do
        local version = info.version
        local oldVersion = string.sub(version, 1, 1) == "v"
        if oldVersion then
            break
        end
        local dartArch = info.dart_sdk_arch
        version = dartArch and (version .. "-" .. dartArch) or version
        table.insert(result, {
            version = version,
            url = getStorageBaseUrl() .. "/flutter_infra_release/releases/" .. info.archive,
            sha256 = info.sha256,
            key = info.hash,
            note = info.channel,
            addition = {
                {
                    name = "dart",
                    version = info.dart_sdk_version
                }
            }
        })
    end
    for _, info in ipairs(ohos.list()) do
        table.insert(result, info)
    end
    table.sort(result, function(a, b)
        local aOhos = ohos.isOhosVersion(a.version)
        local bOhos = ohos.isOhosVersion(b.version)
        if aOhos ~= bOhos then
            return bOhos
        end
        -- Keep the default architecture first, including legacy releases with
        -- no architecture metadata, so @latest cannot select a foreign build.
        local _, aArch = splitVersionAndArch(a.version)
        local _, bArch = splitVersionAndArch(b.version)
        local aDefault = aArch == nil or aArch == type.archType
        local bDefault = bArch == nil or bArch == type.archType
        if aDefault ~= bDefault then
            return aDefault
        end
        local order = compare_versions(a.version, b.version)
        if order ~= 0 then
            return order > 0
        end
        if aArch == type.archType then
            return bArch ~= type.archType
        elseif bArch == type.archType then
            return false
        end
        return a.version < b.version
    end)
    return result
end
