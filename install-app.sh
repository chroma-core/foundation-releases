#!/usr/bin/env bash
set -eo pipefail

# ----------------------------------------------------------------------------
# Foundation Mac app installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/chroma-core/foundation-cli/main/install-app.sh | bash
#   # or via the install host:
#   curl -fsSL https://install.foundation | bash
#   curl -fsSL https://install.foundation/app | bash
#
# Environment variables:
#   FOUNDATION_MAC_VERSION  Install a specific version instead of the latest
#                           stable. Accepts "0.1.0", "v0.1.0", or
#                           "foundation-mac-v0.1.0".
#   FOUNDATION_APP_DIR      Directory that will contain Foundation.app
#                           (default: $HOME/Applications).
#   FOUNDATION_YES          If set to 1, skip interactive prompts (auto-clear
#                           quarantine and open the app).
#   FOUNDATION_NO_OPEN      If set to 1, do not open the app after install.
#   FOUNDATION_NO_XATTR     If set to 1, print quarantine guidance but do not
#                           run xattr (useful for CI that only verifies download).
#
# This script is the single source of truth for the Mac app installer. It lives
# in the (private) chroma-core/foundation repo and is published verbatim to the
# public chroma-core/foundation-cli mirror by the Mac release workflow.
# ----------------------------------------------------------------------------

GITHUB_REPO="chroma-core/foundation-cli"
RELEASE_PREFIX="foundation-mac"
FOUNDATION_APP_DIR="${FOUNDATION_APP_DIR:-${HOME}/Applications}"

if [ -t 1 ]; then
    GREEN='\033[38;2;0;175;0m'
    GREY='\033[38;2;128;128;128m'
    ORANGE='\033[38;2;255;140;0m'
    NC='\033[0m'
else
    GREEN='' GREY='' ORANGE='' NC=''
fi

if [ -t 2 ]; then
    ERR_RED='\033[0;31m'
    ERR_NC='\033[0m'
else
    ERR_RED='' ERR_NC=''
fi

label() { echo -e "${GREY}$1${NC}"; }
code() { echo -e "${ORANGE}$1${NC}"; }
ok() { echo -e "${GREEN}$1${NC}"; }

error() {
    echo -e "${ERR_RED}Error: $1${ERR_NC}" >&2
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || error "'$1' is required but not installed."
}

detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64)          ARCH="amd64" ;;
        aarch64 | arm64) ARCH="arm64" ;;
        *) error "Unsupported architecture: ${ARCH}" ;;
    esac

    if [ "${OS}" != "darwin" ] || [ "${ARCH}" != "arm64" ]; then
        error "Only macOS (Apple Silicon) is supported right now — detected ${OS}/${ARCH}.\nMore platforms are coming. See: https://github.com/${GITHUB_REPO}/releases"
    fi
}

pick_checksum_tool() {
    if command -v shasum >/dev/null 2>&1; then
        SHA_CHECK="shasum -a 256 -c"
    elif command -v sha256sum >/dev/null 2>&1; then
        SHA_CHECK="sha256sum -c"
    else
        error "Need 'shasum' or 'sha256sum' to verify the download."
    fi
}

display_home_path() {
    local path="$1"
    case "${path}" in
        "${HOME}"/*) echo "~${path#"${HOME}"}" ;;
        *) echo "${path}" ;;
    esac
}

# Resolve the release tag into TAG. Prefers FOUNDATION_MAC_VERSION; otherwise
# walks the public mirror's releases API for the newest non-prerelease
# foundation-mac-v* tag. Must not use /releases/latest — that repo also hosts
# foundation-cli-v* releases.
resolve_tag() {
    if [ -n "${FOUNDATION_MAC_VERSION:-}" ]; then
        local v="${FOUNDATION_MAC_VERSION#${RELEASE_PREFIX}-v}"
        v="${v#v}"
        TAG="${RELEASE_PREFIX}-v${v}"
        return
    fi

    require python3

    local json
    json=$(curl -fsSL -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=50") \
        || error "Could not list releases from GitHub.\nPin a version with FOUNDATION_MAC_VERSION=<version>, or see:\n  https://github.com/${GITHUB_REPO}/releases"

    TAG=$(RELEASE_PREFIX="${RELEASE_PREFIX}" python3 -c '
import json, os, sys
prefix = os.environ["RELEASE_PREFIX"] + "-v"
releases = json.load(sys.stdin)
for release in releases:
    if release.get("draft") or release.get("prerelease"):
        continue
    tag = release.get("tag_name") or ""
    if tag.startswith(prefix):
        print(tag)
        break
else:
    sys.exit(1)
' <<< "${json}") || error "No stable ${RELEASE_PREFIX}-v* release found on ${GITHUB_REPO}.\nPin a version with FOUNDATION_MAC_VERSION=<version>, or see:\n  https://github.com/${GITHUB_REPO}/releases"
}

prompt_yes() {
    local prompt="$1"
    if [ "${FOUNDATION_YES:-0}" = "1" ]; then
        return 0
    fi
    if [ ! -t 0 ] && [ ! -e /dev/tty ]; then
        return 1
    fi
    local reply
    if [ -t 0 ]; then
        read -r -p "${prompt} [Y/n] " reply || return 1
    else
        read -r -p "${prompt} [Y/n] " reply </dev/tty || return 1
    fi
    case "${reply}" in
        ""|y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

install_app() {
    local tag="$1"
    local version="${tag#${RELEASE_PREFIX}-v}"
    local asset="${RELEASE_PREFIX}-v${version}_darwin_arm64.zip"
    local base="https://github.com/${GITHUB_REPO}/releases/download/${tag}"
    local app_dest="${FOUNDATION_APP_DIR}/Foundation.app"

    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "${tmp}"' EXIT

    echo -e "${GREY}Downloading ${NC}${ORANGE}${asset}...${NC}"
    curl -fsSL -o "${tmp}/${asset}" "${base}/${asset}" \
        || error "Download failed: ${base}/${asset}\nDoes the release exist? https://github.com/${GITHUB_REPO}/releases/tag/${tag}"
    curl -fsSL -o "${tmp}/${asset}.sha256" "${base}/${asset}.sha256" \
        || error "Checksum file not found: ${base}/${asset}.sha256"

    echo -e "${GREY}Verifying checksum...${NC}"
    ( cd "${tmp}" && ${SHA_CHECK} "${asset}.sha256" >/dev/null ) \
        || error "Checksum verification FAILED for ${asset}. Aborting — the download may be corrupt or tampered with."

    echo -e "${GREY}Extracting...${NC}"
    ditto -x -k "${tmp}/${asset}" "${tmp}/extract" \
        || error "Failed to extract ${asset}."
    [ -d "${tmp}/extract/Foundation.app" ] \
        || error "Foundation.app not found in ${asset}."

    mkdir -p "${FOUNDATION_APP_DIR}" || error "Install directory is not writable: ${FOUNDATION_APP_DIR}"
    if [ -e "${app_dest}" ]; then
        rm -rf "${app_dest}" || error "Could not remove existing app at ${app_dest}"
    fi
    ditto "${tmp}/extract/Foundation.app" "${app_dest}" \
        || error "Failed to install Foundation.app to ${app_dest}"

    local display_path
    display_path=$(display_home_path "${app_dest}")

    echo ""
    ok "✔ Installed successfully!"
    echo ""
    echo -e "  ${GREY}Version:${NC}  ${version}"
    echo -e "  ${GREY}Location:${NC} ${ORANGE}${display_path}${NC}"
    echo ""

    # Developer ID + notarized builds should open under Gatekeeper without
    # clearing quarantine. Keep an optional clear as a fallback for odd local
    # quarantine states (manual zip copies, corporate MDM, etc.).
    if [ "${FOUNDATION_NO_XATTR:-0}" != "1" ]; then
        if spctl --assess --type execute "${app_dest}" >/dev/null 2>&1; then
            echo -e "  ${GREY}Gatekeeper:${NC} signed + notarized — ready to open."
            echo ""
        else
            echo -e "  ${GREY}Gatekeeper:${NC} assessment failed locally; clear quarantine if macOS blocks open:"
            echo ""
            echo -e "    ${ORANGE}xattr -dr com.apple.quarantine ${display_path}${NC}"
            echo ""
            if prompt_yes "Clear quarantine attribute now?"; then
                xattr -dr com.apple.quarantine "${app_dest}" \
                    || error "xattr failed — run the command above manually, then open the app."
                ok "✔ Cleared quarantine."
                echo ""
            else
                echo -e "  ${GREY}Skipped.${NC} Run the xattr command above if Gatekeeper blocks the app."
                echo ""
            fi
        fi
    fi

    if [ "${FOUNDATION_NO_OPEN:-0}" != "1" ]; then
        if prompt_yes "Open Foundation now?"; then
            open "${app_dest}" || error "Failed to open ${app_dest}"
            ok "✔ Launched Foundation."
            echo ""
        fi
    fi

    echo -e "  ${GREY}CLI tip:${NC} install the standalone CLI with ${ORANGE}curl -fsSL install.foundation/cli | bash${NC}"
    echo ""
}

main() {
    label "Installing Foundation (macOS app)..."
    echo ""
    require curl
    require ditto
    require xattr
    detect_platform
    pick_checksum_tool
    resolve_tag
    install_app "${TAG}"
}

main
