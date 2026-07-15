#!/usr/bin/env bash
set -eo pipefail

# ----------------------------------------------------------------------------
# Foundation CLI installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/chroma-core/foundation-cli/main/install.sh | bash
#
# Environment variables:
#   FOUNDATION_VERSION      Install a specific version instead of the latest
#                           stable. Accepts "0.0.9", "v0.0.9", or
#                           "foundation-cli-v0.0.9".
#   FOUNDATION_HOME         Install prefix (default: $HOME/.foundation). The
#                           binary is placed in $FOUNDATION_HOME/bin/foundation.
#   FOUNDATION_INSTALL_DIR  Exact directory to install the binary into. Set by
#                           `foundation update` to the directory of the running
#                           binary so the update replaces it in place. Overrides
#                           FOUNDATION_HOME and skips PATH setup.
#
# This script is the single source of truth for the installer. It lives in the
# (private) chroma-core/foundation repo and is published verbatim to the public
# chroma-core/foundation-cli mirror by the release workflow.
# ----------------------------------------------------------------------------

GITHUB_REPO="chroma-core/foundation-cli"
RELEASE_PREFIX="foundation-cli"
FOUNDATION_HOME="${FOUNDATION_HOME:-${HOME}/.foundation}"

# Semantic colors for installer stdout. Basic ANSI green (32) often renders as
# olive/"puke yellow" on common themes — use the same vivid truecolor green as
# `foundation init` (RGB 0,175,0). Grey labels / orange code match Claude Code
# installer styling. Disabled when stdout isn't a TTY so pipes/logs stay clean.
if [ -t 1 ]; then
    GREEN='\033[38;2;0;175;0m'
    GREY='\033[38;2;128;128;128m'
    ORANGE='\033[38;2;255;140;0m'
    NC='\033[0m'
else
    GREEN='' GREY='' ORANGE='' NC=''
fi

# stderr gets color when stderr is a TTY (errors should stay visible when
# stdout is piped).
if [ -t 2 ]; then
    ERR_RED='\033[0;31m'
    ERR_NC='\033[0m'
else
    ERR_RED='' ERR_NC=''
fi

label() {
    echo -e "${GREY}$1${NC}"
}

code() {
    echo -e "${ORANGE}$1${NC}"
}

ok() {
    echo -e "${GREEN}$1${NC}"
}

error() {
    echo -e "${ERR_RED}Error: $1${ERR_NC}" >&2
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not installed."
}

# Detect OS/arch and normalize to the names used in release asset filenames.
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64)          ARCH="amd64" ;;
        aarch64 | arm64) ARCH="arm64" ;;
        *) error "Unsupported architecture: ${ARCH}" ;;
    esac

    # Only macOS (Apple Silicon) ships today. More platforms coming soon.
    if [ "${OS}" != "darwin" ] || [ "${ARCH}" != "arm64" ]; then
        error "Only macOS (Apple Silicon) is supported right now — detected ${OS}/${ARCH}.\nMore platforms are coming. See: https://github.com/${GITHUB_REPO}/releases"
    fi
}

# Pick a checksum verifier (macOS has shasum; Linux usually sha256sum).
pick_checksum_tool() {
    if command -v shasum >/dev/null 2>&1; then
        SHA_CHECK="shasum -a 256 -c"
    elif command -v sha256sum >/dev/null 2>&1; then
        SHA_CHECK="sha256sum -c"
    else
        error "Need 'shasum' or 'sha256sum' to verify the download."
    fi
}

# Resolve the release tag to install into TAG.
# Honors FOUNDATION_VERSION; otherwise asks GitHub for the latest stable release
# via the /releases/latest redirect (no jq, no auth required).
resolve_tag() {
    if [ -n "${FOUNDATION_VERSION:-}" ]; then
        local v="${FOUNDATION_VERSION#${RELEASE_PREFIX}-v}"
        v="${v#v}"
        TAG="${RELEASE_PREFIX}-v${v}"
        return
    fi

    local final_url
    final_url=$(curl -fsSL -o /dev/null -w '%{url_effective}' \
        "https://github.com/${GITHUB_REPO}/releases/latest") \
        || error "No stable release found (or GitHub unreachable).\nPin a version with FOUNDATION_VERSION=<version>, or see:\n  https://github.com/${GITHUB_REPO}/releases"

    TAG="${final_url##*/tag/}"
    if [ -z "${TAG}" ] || [ "${TAG}" = "${final_url}" ]; then
        error "Could not determine the latest release tag from:\n  ${final_url}\nPin a version with FOUNDATION_VERSION=<version>."
    fi
}

# Shorten $HOME prefix to ~ for Location display (custom prefixes stay absolute).
display_home_path() {
    local path="$1"
    case "${path}" in
        "${HOME}"/*) echo "~${path#"${HOME}"}" ;;
        *) echo "${path}" ;;
    esac
}

# Download, verify, and install the binary for TAG.
install_binary() {
    local tag="$1"
    local version="${tag#${RELEASE_PREFIX}-v}"
    local asset="${RELEASE_PREFIX}-v${version}_${OS}_${ARCH}.tar.gz"
    local base="https://github.com/${GITHUB_REPO}/releases/download/${tag}"

    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "${tmp}"' EXIT

    echo -e "${GREY}Downloading ${NC}${ORANGE}${asset}...${NC}"
    curl -fsSL -o "${tmp}/${asset}" "${base}/${asset}" \
        || error "Download failed: ${base}/${asset}\nDoes the release exist? https://github.com/${GITHUB_REPO}/releases/tag/${tag}"
    curl -fsSL -o "${tmp}/${asset}.sha256" "${base}/${asset}.sha256" \
        || error "Checksum file not found: ${base}/${asset}.sha256"

    echo -e "${GREY}Verifying checksum...${NC}"
    # The sidecar references the bare filename, so verify from inside ${tmp}.
    ( cd "${tmp}" && ${SHA_CHECK} "${asset}.sha256" >/dev/null ) \
        || error "Checksum verification FAILED for ${asset}. Aborting — the download may be corrupt or tampered with."

    tar -xzf "${tmp}/${asset}" -C "${tmp}" || error "Failed to extract ${asset}."
    [ -f "${tmp}/foundation" ] || error "Binary 'foundation' not found in ${asset}."
    chmod +x "${tmp}/foundation"

    # Where the binary lands. `foundation update` sets FOUNDATION_INSTALL_DIR to
    # the directory of the running binary so the update overwrites it in place
    # rather than dropping a second copy somewhere else on (or off) the PATH. A
    # fresh install uses $FOUNDATION_HOME/bin, which setup-path (below) wires up.
    local install_dir
    if [ -n "${FOUNDATION_INSTALL_DIR:-}" ]; then
        install_dir="${FOUNDATION_INSTALL_DIR}"
    else
        install_dir="${FOUNDATION_HOME}/bin"
    fi
    mkdir -p "${install_dir}" || error "Install directory is not writable: ${install_dir}"
    mv "${tmp}/foundation" "${install_dir}/foundation"

    local bin_path="${install_dir}/foundation"
    local display_path
    display_path=$(display_home_path "${bin_path}")

    # Claude-like success summary: vivid green check, grey labels, orange code.
    echo ""
    ok "✔ Installed successfully!"
    echo ""
    echo -e "  ${GREY}Version:${NC}  ${version}"
    echo -e "  ${GREY}Location:${NC} ${ORANGE}${display_path}${NC}"
    echo ""
    echo -e "  ${GREY}Next:${NC} Run ${ORANGE}foundation --help${NC} to get started"

    # Fresh install only: hand PATH setup to the freshly-installed binary. It
    # detects the shell, prompts on /dev/tty (so it works under `curl ... | bash`),
    # edits the rc file, and handles the already-on-PATH / unsupported-shell /
    # no-tty cases itself. `|| true` so a PATH hiccup never fails an otherwise-good
    # install. Skipped during `foundation update`, where the PATH is already set.
    # Blank line before setup-path so any prompt/output doesn't collide with Next.
    if [ -z "${FOUNDATION_INSTALL_DIR:-}" ]; then
        echo ""
        "${install_dir}/foundation" setup-path || true
    fi
}

main() {
    label "Installing Foundation..."
    echo ""
    require curl
    require tar
    detect_platform
    pick_checksum_tool
    resolve_tag
    install_binary "${TAG}"
}

main
