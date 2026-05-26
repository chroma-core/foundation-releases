# Foundation CLI — release mirror

Public distribution point for prebuilt **Foundation CLI** (`foundation`) binaries.

The CLI source is **closed source** and is built in a private Chroma repository.
This repository contains **only the compiled release artifacts** — it is not the
source. Releases here are published automatically by CI on each tagged build.

## Downloads

Prebuilt binaries are attached to each entry on the
[Releases](https://github.com/chroma-core/foundation-cli/releases) page.

Release assets are named:

```
foundation-cli-v<version>_<os>_<arch>.tar.gz
foundation-cli-v<version>_<os>_<arch>.tar.gz.sha256
```

Verify the download before use:

```sh
shasum -a 256 -c foundation-cli-v<version>_<os>_<arch>.tar.gz.sha256
tar -xzf foundation-cli-v<version>_<os>_<arch>.tar.gz
./foundation --version
```

Currently published: macOS (arm64). More platforms to follow.

---

© Chroma. All rights reserved. These binaries are provided for use with Chroma
products; the CLI source is not distributed under an open-source license.
