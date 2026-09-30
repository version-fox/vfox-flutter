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

## GitHub mirror for source installs

On Linux ARM64 and Windows ARM64,
the plugin installs Flutter from git source instead of a prebuilt archive.
If you have difficulty accessing `https://github.com`,
you can set the `VFOX_FLUTTER_GITHUB_MIRROR` environment variable to use a mirror
instead. The value is a URL prefix that is prepended to the GitHub URL.

Common mirror values:

| Mirror               | Value                    |
|----------------------|--------------------------|
| gh-proxy             | `https://gh-proxy.org/`  |

For Bash,

1. You can make the setting take effect temporarily in the current shell using the following command.

```bash
export VFOX_FLUTTER_GITHUB_MIRROR=https://gh-proxy.org/
```

2. To ensure that environment variables always take effect, you can perform the following steps:

```bash
sudo tee /etc/profile.d/myenvvars.sh <<EOF
export VFOX_FLUTTER_GITHUB_MIRROR="https://gh-proxy.org/"
EOF

source /etc/profile.d/myenvvars.sh
```

For PowerShell 7,

1. You can make the setting take effect temporarily in the current shell using the following command.

```powershell
$env:VFOX_FLUTTER_GITHUB_MIRROR = "https://gh-proxy.org/"
```

2. To ensure that environment variables always take effect, you can perform the following steps:

```powershell
[Environment]::SetEnvironmentVariable('VFOX_FLUTTER_GITHUB_MIRROR', 'https://gh-proxy.org/', 'Machine')
```

The mirror only rewrites URLs that start with `https://github.com/`,
so the `FLUTTER_STORAGE_BASE_URL` variable above is unaffected.
