local http = require("http")
local json = require("json")

require("util")
function PLUGIN:PreInstall(ctx)
    local arg = ctx.version
    if arg == "beta" or arg == "dev" or arg == "stable" then
        local type = getOsTypeAndArch()
        local resp, err = http.get({
            url = BASE_URL:format(type.osType)
        })
        if err ~= nil or resp.status_code ~= 200 then
            error("get version failed" .. err)
        end
        local body = json.decode(resp.body)
        local cr = body.current_release
        local key = cr[arg]
        local releases = self:Available({})
        for _, info in ipairs(releases) do
            if info.key == key then
                return {
                    version = info.version,
                    url = info.url,
                    sha256 = info.sha256
                }
            end
        end
    end
    local releases = self:Available({})
    for _, info in ipairs(releases) do
        if info.version == arg then
            return {
                version = info.version,
                url = info.url,
                sha256 = info.sha256
            }
        end
    end
    return nil
end