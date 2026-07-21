#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
package_nix="$repo_root/pkgs/bun-canary/package.nix"

# Fetch canary release info to get the exact commit it was built from
release_json=$(curl -fsSL "https://api.github.com/repos/oven-sh/bun/releases/tags/canary")
commit=$(echo "$release_json" | jq -r '.body' | sed -n 's/.*commit: \([a-f0-9]\{40\}\).*/\1/p')

if [[ -z "$commit" || "$commit" == "null" ]]; then
  echo "ERROR: Could not extract commit from canary release body"
  exit 1
fi

# Fetch the commit date
date=$(curl -fsSL "https://api.github.com/repos/oven-sh/bun/commits/$commit" | jq -r '.commit.committer.date' | tr -d '-' | cut -c1-8)

# Fetch SHA256SUMS.txt from canary release for all asset hashes
hashes_txt=$(curl -fsSL "https://github.com/oven-sh/bun/releases/download/canary/SHASUMS256.txt")

# Update commit and date in package.nix
sed -i "s/^  commit = \"[a-f0-9]*\";$/  commit = \"$commit\";/" "$package_nix"
sed -i "s/^  date = \"[0-9]*\";$/  date = \"$date\";/" "$package_nix"

# Update hashes for each asset from SHASUMS256.txt
for asset in bun-darwin-aarch64.zip bun-linux-aarch64.zip bun-linux-x64.zip; do
  # Extract hex hash from SHASUMS256.txt (format: "<hex>  <filename>")
  hex_hash=$(echo "$hashes_txt" | grep "  $asset$" | awk '{print $1}')
  if [[ -z "$hex_hash" ]]; then
    echo "ERROR: Could not find hash for $asset in SHASUMS256.txt"
    exit 1
  fi
  sri_hash=$(nix hash convert --to sri --hash-algo sha256 "$hex_hash")
  sed -i "/$asset/,/hash/{s|hash = \".*\"|hash = \"$sri_hash\"|}" "$package_nix"
done

echo "Updated $package_nix"
echo "commit=$commit"
echo "date=$date"
