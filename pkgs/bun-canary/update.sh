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

# Update commit and date first
sed -i "s/^  commit = \"[a-f0-9]*\";$/  commit = \"$commit\";/" "$package_nix"
sed -i "s/^  date = \"[0-9]*\";$/  date = \"$date\";/" "$package_nix"

# Download each asset and compute its hash, then update package.nix
# This avoids race conditions with the moving canary tag.
for asset in bun-darwin-aarch64.zip bun-linux-aarch64.zip bun-linux-x64.zip; do
  url="https://github.com/oven-sh/bun/releases/download/canary/$asset"
  echo "Downloading $asset..."
  hash_info=$(nix store prefetch-file --json --hash-type sha256 "$url" 2>/dev/null || true)
  if [[ -z "$hash_info" ]]; then
    echo "ERROR: Failed to download $asset"
    exit 1
  fi
  sri_hash=$(echo "$hash_info" | jq -r '.hash')
  echo "  hash: $sri_hash"
  sed -i "/$asset/,/hash/{s|hash = \".*\"|hash = \"$sri_hash\"|}" "$package_nix"
done

echo "Updated $package_nix"
echo "commit=$commit"
echo "date=$date"
