#!/usr/bin/env sh
# SPDX-FileCopyrightText: 2026 k0s authors
# SPDX-License-Identifier: Apache-2.0

set -eu

if [ $# -eq 0 ] || [ "$1" = '-h' ] || [ "$1" = '--help' ] || { [ "$1" = -- ] && [ $# -eq 1 ]; }; then
  echo 'Combine multi-platform OCI images. Use like so:'
  echo
  echo "  $0 [--] <output-dir> <archive-file-1> <archive-file-2> ..."
  echo "  $0 < -h | --help >"
  exit 0
fi

[ "$1" != -- ] || shift
out=$1
shift

mkdir -p -- "$out"

index='{"schemaVersion": 2, "mediaType": "application/vnd.oci.image.index.v1+json", "manifests": []}'

while [ $# -gt 0 ]; do
  tar xf "$1" -C "$out" blobs/ index.json oci-layout

  nextIndex="$out/index.json"
  content=$(jq -r '.manifests[0] | "\(.mediaType) \(.digest)"' "$nextIndex")

  case "${content%% *}" in
  application/vnd.oci.image.index.v1+json)
    content=${content#* }
    nextIndex="$out/blobs/${content%%:*}/${content#*:}"
    ;;
  esac

  index=$(IDX=$index jq '.manifests as $next | $ENV.IDX | fromjson | .manifests += $next' "$nextIndex")
  rm -f -- "$nextIndex"
  shift
done

sum=$(printf %s "$index" | sha256sum)
sum=${sum%% *}

[ -f "$out/blobs/sha256/$sum" ] || printf %s "$index" >"$out/blobs/sha256/$sum"
IDX=$index SUM=$sum jq -n '($ENV.IDX | fromjson) as $idx | $idx | .manifests = [{mediaType: $idx.mediaType, digest: "sha256:\($ENV.SUM)", size: ($ENV.IDX | length)}]' >"$out/index.json"

chmod 444 -- "$out/blobs/sha256/$sum"
touch -r "$out/oci-layout" -- "$out/index.json" "$out/blobs/sha256/$sum"

echo sha256:"$sum"
