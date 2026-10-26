#!/usr/bin/env bash
# Bump .github/tool-versions.env to the newest stable Quarto and lychee releases
# that have been public for at least COOLDOWN_DAYS. Each new hash must agree
# across three sources (GitHub's asset digest, the project's own checksum file,
# and our own hash of the download) or the script fails loudly.
# Needs: gh (authenticated via GH_TOKEN), curl, jq-capable gh.
set -euo pipefail
cd "$(dirname "$0")/.."
source tool-versions.env
COOLDOWN_DAYS="${COOLDOWN_DAYS:-7}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fetch() { curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 -o "$2" "$1"; }
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

# Newest non-draft, non-prerelease tag older than the cooldown.
newest_settled_tag() {
  gh api "repos/$1/releases?per_page=100" --jq "
    [ .[] | select((.draft or .prerelease) | not)
          | select((.published_at | fromdateiso8601) <= (now - ${COOLDOWN_DAYS} * 86400)) ]
    | first | .tag_name // empty"
}

# Prints the verified SHA-256 of a release asset, or exits non-zero.
#   verified_sha256 REPO TAG ASSET CHECKSUM_FILE_URL
verified_sha256() {
  local repo="$1" tag="$2" asset="$3" sums_url="$4" api file published
  api="$(gh api "repos/$repo/releases/tags/$tag" --jq ".assets[] | select(.name == \"$asset\") | .digest" | sed 's/^sha256://')"
  fetch "https://github.com/$repo/releases/download/$tag/$asset" "$tmp/$asset"
  file="$(sha256 "$tmp/$asset")"
  fetch "$sums_url" "$tmp/sums"
  published="$(awk -v a="$asset" '$2 == a || $2 == "*"a { print $1 }' "$tmp/sums")"
  if [[ -z "$api" || "$api" != "$file" || "$published" != "$file" ]]; then
    echo "::error::Checksum mismatch for $repo $tag $asset (api=$api published=$published file=$file)" >&2
    return 1
  fi
  echo "$file"
}

tag="$(newest_settled_tag quarto-dev/quarto-cli)"
new_quarto="${tag#v}"
if [[ -n "$new_quarto" && "$new_quarto" != "$QUARTO_VERSION" ]]; then
  echo "Quarto: $QUARTO_VERSION -> $new_quarto"
  QUARTO_SHA256="$(verified_sha256 quarto-dev/quarto-cli "$tag" "quarto-${new_quarto}-linux-amd64.deb" \
    "https://github.com/quarto-dev/quarto-cli/releases/download/$tag/quarto-${new_quarto}-checksums.txt")"
  QUARTO_VERSION="$new_quarto"
else
  echo "Quarto: $QUARTO_VERSION is current"
fi

tag="$(newest_settled_tag lycheeverse/lychee)"
new_lychee="${tag#lychee-v}"
if [[ -n "$new_lychee" && "$new_lychee" != "$LYCHEE_VERSION" ]]; then
  echo "lychee: $LYCHEE_VERSION -> $new_lychee"
  asset="lychee-x86_64-unknown-linux-gnu.tar.gz"
  LYCHEE_SHA256="$(verified_sha256 lycheeverse/lychee "$tag" "$asset" \
    "https://github.com/lycheeverse/lychee/releases/download/$tag/$asset.sha256")"
  LYCHEE_VERSION="$new_lychee"
else
  echo "lychee: $LYCHEE_VERSION is current"
fi

cat > tool-versions.env <<VERSIONS
# Pinned build tools. Updated automatically by .github/workflows/update-tools.yml
# (weekly PR); every hash is checked against three independent sources first.
QUARTO_VERSION=$QUARTO_VERSION
QUARTO_SHA256=$QUARTO_SHA256
LYCHEE_VERSION=$LYCHEE_VERSION
LYCHEE_SHA256=$LYCHEE_SHA256
VERSIONS
