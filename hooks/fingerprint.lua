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

local manifest = require("manifest")

-- The fact that identifies a Flutter installation: the commit its git
-- checkout is at. vfox records it in the version's receipt on install and
-- link, and `vfox use` and `vfox doctor` warn when it is no longer the same
-- (for example after `flutter upgrade` moved the SDK in place), with
-- `vfox install --reinstall` as the way out.
--
-- The hook runs on every `vfox use`, so it only reads files: no processes, no
-- network. A nil return means there is nothing to check (no `.git`), and vfox
-- stays silent: SDKs without a git checkout are left alone.
function PLUGIN:Fingerprint(ctx)
    if type(ctx) ~= "table" then
        return nil
    end
    local path = ctx.path
    local version = ctx.version
    local head = manifest.fingerprintHead(path, version)
    if (head == nil or head == "") and ctx.sdkInfo ~= nil and PLUGIN ~= nil and PLUGIN.name ~= nil then
        local info = ctx.sdkInfo[PLUGIN.name]
        if info ~= nil and type(info.path) == "string" and info.path ~= path then
            head = manifest.fingerprintHead(info.path, version or info.version)
        end
    end
    if head == nil or head == "" then
        return nil
    end
    return {
        facts = {
            head = head,
        },
    }
end
