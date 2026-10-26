#!/usr/bin/env bash
# Install the Quarto and lychee versions pinned in .github/tool-versions.env.
# Refuses to install anything whose SHA-256 doesn't match the pinned hash.
set -euo pipefail
source "$(dirname "$0")/../tool-versions.env"

tmp="$(mktemp -d "${RUNNER_TEMP:-/tmp}/tools.XXXXXX")"
fetch() { curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 -o "$2" "$1"; }
verify() { echo "$2  $1" | sha256sum --check --strict; }

deb="quarto-${QUARTO_VERSION}-linux-amd64.deb"
fetch "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/${deb}" "$tmp/$deb"
verify "$tmp/$deb" "$QUARTO_SHA256"
sudo dpkg -i "$tmp/$deb"

tgz="lychee-x86_64-unknown-linux-gnu.tar.gz"
fetch "https://github.com/lycheeverse/lychee/releases/download/lychee-v${LYCHEE_VERSION}/${tgz}" "$tmp/$tgz"
verify "$tmp/$tgz" "$LYCHEE_SHA256"
mkdir "$tmp/lychee" && tar -xzf "$tmp/$tgz" -C "$tmp/lychee"
sudo install -m 0755 "$(find "$tmp/lychee" -type f -name lychee | head -n 1)" /usr/local/bin/lychee

quarto --version
lychee --version
