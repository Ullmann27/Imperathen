#!/usr/bin/env bash
set -euo pipefail
target="$(realpath -m "$1")"
mkdir -p "$target"
cd "$target"
version=4.3.2
archive="blender-${version}-linux-x64.tar.xz"
base="https://download.blender.org/release/Blender4.3"
curl --fail --silent --show-error --location --retry 3 "$base/blender-${version}.sha256" -o checksums.txt
curl --fail --silent --show-error --location --retry 3 "$base/$archive" -o "$archive"
awk -v n="$archive" '$2 == n || $2 == "*" n {print $1 "  " n}' checksums.txt > selected.sha256
test "$(wc -l < selected.sha256)" -eq 1
sha256sum -c selected.sha256
tar -xJf "$archive" --strip-components=1
test -x ./blender
./blender --version
