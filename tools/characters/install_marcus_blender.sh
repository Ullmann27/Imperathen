#!/usr/bin/env bash
set -euo pipefail
target="$(realpath -m "$1")"
mkdir -p "$target"
cd "$target"
version=4.3.2
archive="blender-${version}-linux-x64.tar.xz"
# Both endpoints are Blender's official distribution hosts. The archive must
# match an authentic published SHA256 before it can ever be extracted.
download() {
  local name="$1" dest="$2" base
  for base in https://download.blender.org/release/Blender4.3 https://mirror.blender.org/release/Blender4.3; do
    rm -f "$dest.part"
    if curl --fail --silent --show-error --location --retry 2 --connect-timeout 20 --max-time 600 "$base/$name" -o "$dest.part"; then
      mv "$dest.part" "$dest"
      return 0
    fi
  done
  echo "Official Blender distribution unavailable: $name" >&2
  return 1
}
download "blender-${version}.sha256" checksums.txt
awk -v n="$archive" '$2 == n || $2 == "*" n {print $1 "  " n}' checksums.txt > selected.sha256
test "$(wc -l < selected.sha256)" -eq 1
grep -Eq '^[0-9a-fA-F]{64}  blender-4\.3\.2-linux-x64\.tar\.xz$' selected.sha256
download "$archive" "$archive"
sha256sum -c selected.sha256
tar -xJf "$archive" --strip-components=1
test -x ./blender
./blender --version
