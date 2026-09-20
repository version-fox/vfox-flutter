# Install from source

## Ubuntu 26.04.1

Execute in Bash,

```bash
git clone --depth 1 https://github.com/version-fox/vfox-flutter.git
cd ./vfox-flutter/
zip -qr ./flutter.zip metadata.lua hooks lib
vfox add flutter --source ./flutter.zip
```

You can verify this using the following command,

```bash
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
flutter --version --no-version-check
dart --version
```

## Windows 11

Assume that PowerShell 7 is already installed. Execute in PowerShell 7,

```powershell
winget install --id Git.Git --source winget --exact
git clone --depth 1 https://github.com/version-fox/vfox-flutter.git
cd ./vfox-flutter/
tar -a -cf ./flutter.zip metadata.lua hooks lib
vfox add flutter --source ./flutter.zip
```

You can verify this using the following command,

```powershell
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
flutter --version --no-version-check
dart --version
```
