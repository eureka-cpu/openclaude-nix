#!/usr/bin/env nix
#!nix shell nixpkgs#bash nixpkgs#nodejs_22 nixpkgs#curl nixpkgs#nix nixpkgs#gnused nixpkgs#coreutils nixpkgs#git --command bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"
PKG_NIX="$SCRIPT_DIR/openclaude.nix"
LOCKFILE="$SCRIPT_DIR/package-lock.json"

# Fetch latest version from the npm registry
version="$(npm view @gitlawb/openclaude version)"
echo "Updating to $version..."

# Update the version string
sed -i "s|version = \"[^\"]*\";|version = \"$version\";|" "$PKG_NIX"

# Regenerate package-lock.json from the new tarball
tarball="https://registry.npmjs.org/@gitlawb/openclaude/-/openclaude-${version}.tgz"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

curl -fsSL "$tarball" | tar -xz -C "$tmpdir"
(cd "$tmpdir/package" && npm install --package-lock-only --ignore-scripts --silent)
cp "$tmpdir/package/package-lock.json" "$LOCKFILE"
echo "Regenerated package-lock.json"

# Recompute the fetchzip src hash
sed -i 's|hash = "sha256-[^"]*";|hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";|' "$PKG_NIX"
git -C "$FLAKE_DIR" add "$PKG_NIX" "$LOCKFILE"
src_hash="$(
  nix build "${FLAKE_DIR}#openclaude" --no-link 2>&1 \
    | sed -nE 's/.*got:[[:space:]]+(sha256-[A-Za-z0-9+/=-]+).*/\1/p' \
    | head -1
)"
[ -n "$src_hash" ] || { echo "error: failed to determine src hash" >&2; exit 1; }
sed -i "s|hash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";|hash = \"$src_hash\";|" "$PKG_NIX"
echo "Updated src hash: $src_hash"

# Recompute npmDepsHash
sed -i 's|npmDepsHash = "sha256-[^"]*";|npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";|' "$PKG_NIX"
git -C "$FLAKE_DIR" add "$PKG_NIX"
deps_hash="$(
  nix build "${FLAKE_DIR}#openclaude" --no-link 2>&1 \
    | sed -nE 's/.*got:[[:space:]]+(sha256-[A-Za-z0-9+/=-]+).*/\1/p' \
    | head -1
)"
[ -n "$deps_hash" ] || { echo "error: failed to determine npmDepsHash" >&2; exit 1; }
sed -i "s|npmDepsHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";|npmDepsHash = \"$deps_hash\";|" "$PKG_NIX"
echo "Updated npmDepsHash: $deps_hash"

echo "Done."
