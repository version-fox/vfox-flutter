
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