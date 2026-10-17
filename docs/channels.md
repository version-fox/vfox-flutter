# Channels

`stable` and `beta` install the release the channel currently points to, and also
accept an architecture suffix such as `stable-x64` (see `arm64.md`):

```bash
vfox install flutter@stable
```

- **Resolved at install time.** The SDK is installed under the version the channel
  points to, such as `flutter@3.47.4` (`flutter@3.47.4-x64` for `stable-x64`), and
  vfox prints that version when the install finishes.
- **Use the version, not the channel.** `vfox use flutter@stable` fails with
  `flutter@stable is not installed`; run `vfox use --global flutter@3.47.4` instead.
  `vfox uninstall` takes the version as well.
- **Channels are not followed.** Once the channel moves to a new release,
  `vfox install flutter@stable` installs it next to the old one; switch to it with
  `vfox use`.

Flutter retired the `dev` channel, whose last release is `2.13.0-0.1.pre` from April 2022,
so the plugin does not accept it.
