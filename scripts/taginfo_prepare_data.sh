#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="/data/www/html/static/openstreetmap/taginfo/20260130"
DEST_DIR="$(pwd)/data/taginfo"

mkdir -p "$DEST_DIR"

if [ ! -d "$SRC_DIR" ]; then
  echo "Missing source dir: $SRC_DIR" >&2
  exit 1
fi

found_any=false
for src in "$SRC_DIR"/taginfo-*.db.bz2; do
  if [ ! -f "$src" ]; then
    continue
  fi
  found_any=true
  base_name="$(basename "$src" .bz2)"
  tmp_file="${DEST_DIR}/.${base_name}.tmp"
  out_file="${DEST_DIR}/${base_name}"

  echo "Extracting ${src} -> ${out_file}"
  bzip2 -dc "$src" > "$tmp_file"
  mv -f "$tmp_file" "$out_file"
done

if [ "$found_any" = false ]; then
  echo "No taginfo-*.db.bz2 found in $SRC_DIR" >&2
  exit 1
fi

echo "Taginfo databases prepared in $DEST_DIR"
