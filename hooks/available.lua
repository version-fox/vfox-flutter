local http = require("http")
local json = require("json")

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
        table.insert(result, {
            version = info.version,
            url = body.base_url .. "/" .. info.archive,
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
    return result
end
