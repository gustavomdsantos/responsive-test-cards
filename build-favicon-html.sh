#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# "Makefile" for building embedded Favicons in HTML files from SVGs
#
# Author: Gustavo Moraes
# License: MIT
# Homepage: https://github.com/gustavomdsantos/responsive-test-cards
#####################################################################

SVG="favicon.svg"
HTML="favicon-links.html"

TMPDIR="$(mktemp -d)"
ICO="$TMPDIR/favicon.ico"
APPLEPNG="$TMPDIR/apple-touch-icon.png"

IM_CMD=""

# ---------- utils ----------

die() {
  echo "Error: $*" >&2
  exit 1
}

require() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# ---------- checks ----------

detect_imagemagick() {
  if require magick; then
    IM_CMD="magick"
  elif require convert; then
    IM_CMD="convert"
  else
    die "ImageMagick not found (magick or convert required)"
  fi
}

check_dependencies() {
  for cmd in base64 sed tr; do
    require "$cmd" || die "required command not found: $cmd"
  done
}

check_inputs() {
  [[ -f "$SVG" ]] || die "source SVG not found: $SVG"
}

# ---------- build steps ----------

# SVG rasterization density in ImageMagick:
# density = 72 * (target_px / svg_px) * oversample
# oversample: 2 = sharp enough, 4 = pixel-perfect

build_ico() {
  # Density with 4x Oversample: 72×(48÷16)×4 = 864
  "$IM_CMD" \
    -density 864 \
    -background none \
    "$SVG" \
    -define icon:auto-resize=16,32,48 \
    -strip \
    -define png:compression-level=9 \
    -define png:compression-strategy=1 \
    "$ICO"
}

build_apple_png() {
  # Density with 4x Oversample: 72×(180÷16)×4 = 3240
  "$IM_CMD" \
    -density 3240 \
    -background none \
    "$SVG" \
    -resize 180x180 \
    -strip \
    -define png:compression-level=9 \
    -define png:compression-strategy=1 \
    "$APPLEPNG"
}

# ---------- encoders ----------

encode_svg_data_uri() {
  sed \
    -e 's/%/%25/g' \
    -e 's/#/%23/g' \
    -e 's/</%3C/g' \
    -e 's/>/%3E/g' \
    -e "s/\"/'/g" \
    "$SVG" | tr -d '\n'
}

b64() {
  base64 -w0 "$1"
}

# ---------- output ----------

generate_html() {
  local ico_b64 svg_data apple_b64

  ico_b64="$(b64 "$ICO")"
  svg_data="$(encode_svg_data_uri)"
  apple_b64="$(b64 "$APPLEPNG")"

  cat > "$HTML" <<EOF
<!-- Auto-generated. DO NOT EDIT BY HAND -->

<link rel="icon" href="data:image/x-icon;base64,${ico_b64}">
<link rel="icon" type="image/svg+xml" href="data:image/svg+xml,${svg_data}">
<link rel="apple-touch-icon" href="data:image/png;base64,${apple_b64}">
EOF
}

# ---------- main ----------

main() {
  detect_imagemagick
  check_dependencies
  check_inputs
  build_ico
  build_apple_png
  generate_html
  echo "✔ Generated: $HTML"
}

main "$@"
