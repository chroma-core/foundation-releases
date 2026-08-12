# Foundation — release mirror

Public distribution point for prebuilt **Foundation** binaries:

- **CLI** (`foundation`) — `foundation-cli-v*` releases
- **Mac app** (`Foundation.app`) — `foundation-mac-v*` releases

Source is **closed** and is built in a private Chroma repository. This repository
contains **only compiled release artifacts and install scripts** — it is not the
source. Releases here are published automatically by CI on each tagged build.

## Install

### Mac app (default)

```sh
curl -fsSL https://install.foundation | bash
# or:
curl -fsSL https://raw.githubusercontent.com/chroma-core/foundation-releases/main/install-app.sh | bash
```

### CLI

```sh
curl -fsSL https://install.foundation/cli | bash
# or:
curl -fsSL https://raw.githubusercontent.com/chroma-core/foundation-releases/main/install.sh | bash
```

The CLI installer downloads the right binary for your platform, verifies its
sha256, and installs it to `~/.foundation/bin/foundation`.

CLI options (environment variables):

- `FOUNDATION_VERSION` — install a specific version (e.g. `FOUNDATION_VERSION=0.0.9`)
  instead of the latest stable release.
- `FOUNDATION_HOME` — install prefix (default `~/.foundation`); the binary lands in
  `$FOUNDATION_HOME/bin`.

Currently supported: macOS (Apple Silicon). More platforms to follow.

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
