# Mirror

By default, Flutter SDK is downloaded from `https://storage.googleapis.com`.
If you have difficulty accessing it, you can set the `FLUTTER_STORAGE_BASE_URL` environment variable to use a mirror.

Common mirror values:

| Mirror                                        | URL                                     |
|-----------------------------------------------|-----------------------------------------|
| CFUG (China Flutter User Group)               | `https://storage.flutter-io.cn`         |
| CERNET (China Education and Research Network) | `https://mirrors.cernet.edu.cn/flutter` |

For an up-to-date list of available mirrors, refer to the MirrorZ Help
site: https://help.mirrors.cernet.edu.cn/flutter/ .

## Ubuntu 26.04.1

For Bash, 

1. You can make the setting take effect temporarily in the current shell using the following command.

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

2. To ensure that environment variables always take effect, you can perform the following steps:

```bash
sudo tee /etc/profile.d/myenvvars.sh <<EOF
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
EOF

source /etc/profile.d/myenvvars.sh
```

## Windows 11

For PowerShell 7,

1. You can make the setting take effect temporarily in the current shell using the following command.

```powershell
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

2. To ensure that environment variables always take effect, you can perform the following steps:

```powershell
[Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'Machine')
```
