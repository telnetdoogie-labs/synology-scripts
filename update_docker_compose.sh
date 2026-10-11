#!/bin/bash

# inspired by https://gist.github.com/deviantony/2b5078fe1675a5fedabf1de3d1f2652a

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please run with sudo."
   exit 1
fi

#find docker-compose
COMPOSE_EXEC=$(which docker-compose)

if [[ -z "${COMPOSE_EXEC}"  ]]; then
    echo "Error: docker-compose not found in system path."
    exit 1
fi

#get path to the real docker-compose binary
# readlink -f works whether docker-compose is a symlink (absolute or relative) or a regular file
COMPOSE_PATH=$(dirname "$(readlink -f "${COMPOSE_EXEC}")")
COMPOSE_BIN="${COMPOSE_PATH}/docker-compose"

if [[ ! -f "${COMPOSE_BIN}" ]]; then
    echo "Error: could not locate docker-compose binary (resolved to ${COMPOSE_BIN})."
    exit 1
fi

force=0
for arg in "$@"; do
    if [ "$arg" == "--force" ]; then
        force=1
    fi
done

CURRENT_COMPOSE_VER=$(docker-compose version | sed -n -e "s/^.*version\ //p")
LATEST_COMPOSE_VER=$(curl -fsS https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')

echo "Current version of docker-compose: $CURRENT_COMPOSE_VER"
echo "Latest version of docker-compose: $LATEST_COMPOSE_VER"
echo

# Don't proceed if GitHub didn't give us a version (rate limited, offline, etc.)
if [[ -z "$LATEST_COMPOSE_VER" || "$LATEST_COMPOSE_VER" == "null" ]]; then
    echo "Error: could not determine the latest docker-compose version from GitHub."
    exit 1
fi

if [[ "$CURRENT_COMPOSE_VER" = "$LATEST_COMPOSE_VER" ]]; then
    echo "Latest version of docker-compose already installed!"
    if [ ! "$force" -eq 1 ]; then
        echo " - Exiting."
        exit 0
    else
        echo " - forcing update"
    fi
fi

echo
echo "Installing latest version of docker-compose..."

DOWNLOAD_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
TMP_FILE="${COMPOSE_PATH}/docker-compose.download.$$"
trap 'rm -f "$TMP_FILE"' EXIT

# Download to a temp file first; -f makes curl fail on HTTP errors instead of saving an error page
echo "Downloading ${DOWNLOAD_URL}..."
if ! curl -fsSL "$DOWNLOAD_URL" -o "$TMP_FILE"; then
    echo "Error: download failed. Existing docker-compose left untouched."
    exit 1
fi
chmod 755 "$TMP_FILE"

# Make sure the downloaded binary actually runs before swapping it in
if ! "$TMP_FILE" version >/dev/null 2>&1; then
    echo "Error: downloaded file is not a working docker-compose binary. Existing docker-compose left untouched."
    exit 1
fi

echo "Backing up current version of docker-compose..."
echo "  creating backup << ${COMPOSE_BIN}.${CURRENT_COMPOSE_VER} >>"
if ! mv "$COMPOSE_BIN" "${COMPOSE_BIN}.${CURRENT_COMPOSE_VER}"; then
    echo "Error: could not back up existing docker-compose."
    exit 1
fi

if ! mv "$TMP_FILE" "$COMPOSE_BIN"; then
    echo "Error: could not install new docker-compose; restoring backup."
    mv "${COMPOSE_BIN}.${CURRENT_COMPOSE_VER}" "$COMPOSE_BIN"
    exit 1
fi
echo "  new docker-compose created"

NEW_COMPOSE_VER=$(docker-compose version | sed -n -e "s/^.*version\ //p")

BLUE="\033[0;34m"
NC="\033[0m"
echo -e "New version of docker-compose returns: ${BLUE} ${NEW_COMPOSE_VER} ${NC}"
echo
echo "  to revert / replace with previous version, use the following command:"
echo -e "  ${BLUE}sudo mv ${COMPOSE_BIN}.${CURRENT_COMPOSE_VER} ${COMPOSE_BIN}${NC}"
echo
