# vfox-flutter
Flutter plugin for [vfox](https://vfox.lhan.me/).


## Install

After installing [vfox](https://github.com/version-fox/vfox), install the plugin by running:

```bash
vfox add flutter
```

### Example: Ubuntu 26.04

```bash
vfox add flutter
vfox install flutter@3.44.0
sudo apt install --assume-yes curl git unzip xz-utils zip libglu1-mesa
vfox use --global flutter@3.44.0
```

## Mirror

By default, Flutter SDK is downloaded from `https://storage.googleapis.com`. 
If you have difficulty accessing it, you can set the `FLUTTER_STORAGE_BASE_URL` environment variable to use a mirror.

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

Common mirror values:

| Mirror                               | URL                                        |
|--------------------------------------|--------------------------------------------|
| China Flutter User Group (CFUG)      | `https://storage.flutter-io.cn`            |
| SJTU (Shanghai Jiao Tong University) | `https://mirror.sjtu.edu.cn/flutter_infra` |

For an up-to-date list of available mirrors, refer to the MirrorZ Help site: https://help.mirrors.cernet.edu.cn/flutter/ .
