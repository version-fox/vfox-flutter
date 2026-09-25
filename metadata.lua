--- !!! DO NOT EDIT OR RENAME !!!
PLUGIN = {}

--- !!! MUST BE SET !!!
--- Plugin name
PLUGIN.name = "flutter"
--- Plugin version
PLUGIN.version = "0.2.2"
--- Plugin homepage
PLUGIN.homepage = "https://github.com/version-fox/vfox-flutter"
--- Plugin license, please choose a correct license according to your needs.
PLUGIN.license = "Apache 2.0"
--- Plugin description
PLUGIN.description = "Flutter plugin, https://flutter.dev"


--- !!! OPTIONAL !!!
--[[
NOTE:
    Minimum compatible vfox version.
    If the plugin is not compatible with the current vfox version,
    vfox will not load the plugin and prompt the user to upgrade vfox.
 --]]
PLUGIN.minRuntimeVersion = "0.3.0"
-- Some things that need user to be attention!
PLUGIN.notes = {
    "Do NOT run `flutter upgrade` (or `flutter downgrade`, `flutter channel`, or any in-place git operation) inside a vfox-managed Flutter SDK. It mutates the SDK in place and vfox will silently hand you the wrong version on the next `vfox use`. Change versions with `vfox install flutter@<version>` and `vfox use flutter@<version>`. This plugin detects such drift and prints a warning with the restore commands on the next `vfox use`.",
}
