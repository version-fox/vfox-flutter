
BASE_URL = "https://storage.googleapis.com/flutter_infra_release/releases/releases_%s.json"


function getOsTypeAndArch()
    local osType = RUNTIME.osType
    local archType = RUNTIME.archType
    if osType == "darwin" then
        osType = "macos"
    end
    if archType == "amd64" then
        archType = "x64"
    elseif archType == "arm64" then
        archType = "arm64"
    else
        error("flutter does not support" .. archType .. "architecture")
    end
    return {
        osType = osType, archType = archType
    }
end

function compare_versions(v1, v2)
    local v1_parts = {}
    for part in string.gmatch(v1, "%d+") do
        table.insert(v1_parts, tonumber(part))
    end

    local v2_parts = {}
    for part in string.gmatch(v2, "%d+") do
        table.insert(v2_parts, tonumber(part))
    end

    for i = 1, math.max(#v1_parts, #v2_parts) do
        local v1_part = v1_parts[i] or math.huge
        local v2_part = v2_parts[i] or math.huge
        if v1_part > v2_part then
            return 1
        elseif v1_part < v2_part then
            return -1
        end
    end

    return 0
end