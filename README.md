# Foundation — release mirror

Public distribution point for prebuilt **Foundation** binaries:

- **CLI** (`foundation`) — `foundation-cli-v*` releases
- **Mac app** (`Foundation.app`) — `foundation-mac-v*` releases

Source is **closed** and is built in a private Chroma repository. This repository
contains **only compiled release artifacts** — it is not the source. Releases here
are published automatically by CI on each tagged build.

## Install

Download the latest Mac app from https://install.foundation (or the
[Releases](https://github.com/chroma-core/foundation-releases/releases) page).
Open the disk image and drag `Foundation.app` onto Applications.

The CLI ships inside the app at `Contents/Resources/foundation`.

## Downloads (manual)

Prebuilt binaries are attached to each entry on the
[Releases](https://github.com/chroma-core/foundation-releases/releases) page.

CLI release assets are named:

```
foundation-cli-v<version>_<os>_<arch>.tar.gz
foundation-cli-v<version>_<os>_<arch>.tar.gz.sha256
```

Mac app release assets are named:

```
Foundation-<version>-arm64.zip
Foundation-<version>-arm64.zip.sha256
```

Verify a CLI download before use:

```sh
shasum -a 256 -c foundation-cli-v<version>_<os>_<arch>.tar.gz.sha256
tar -xzf foundation-cli-v<version>_<os>_<arch>.tar.gz
./foundation version
```

---

© Chroma. All rights reserved. These binaries are provided for use with Chroma
products; the source is not distributed under an open-source license.
