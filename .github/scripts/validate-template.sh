#!/usr/bin/env bash
set -euo pipefail

template=${1:?template path required}
: "${GITHUB_OUTPUT:=}"

bash -n "$template"
pkgname=$(sed -n 's/^pkgname=//p' "$template")
version=$(sed -n 's/^version=//p' "$template")
revision=$(sed -n 's/^revision=//p' "$template")
_rev=$(sed -n 's/^_rev=//p' "$template")
checksum=$(sed -n 's/^checksum=//p' "$template")
distfiles=$(sed -n 's/^distfiles="//p' "$template" | sed 's/"$//')

: "${pkgname:?}" "${version:?}" "${revision:?}" "${_rev:?}" "${checksum:?}" "${distfiles:?}"

[ "$pkgname" = "librewolf" ] || {
  echo "workflow is only valid for pkgname=librewolf" >&2
  exit 1
}

[[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] || {
  echo "invalid LibreWolf version: $version" >&2
  exit 1
}

[[ "$revision" =~ ^[1-9][0-9]*$ ]] || {
  echo "revision must be a positive integer: $revision" >&2
  exit 1
}

[[ "$_rev" =~ ^[0-9]+$ ]] || {
  echo "_rev must be a non-negative integer: $_rev" >&2
  exit 1
}

printf '%s\n' "$checksum" | grep -Eq '^[0-9A-Fa-f]{64}$' || {
  echo "template checksum must be exactly one 64-character SHA-256 digest" >&2
  exit 1
}

set -- $distfiles
[ "$#" -eq 1 ] || {
  echo "template must contain exactly one distfile URL" >&2
  exit 1
}

case "$1" in
  https://*) ;;
  *) echo "distfile must use HTTPS: $1" >&2; exit 1 ;;
esac

expected_template_distfile='${pkgname}-${version}-${_rev}.source.tar.gz'
expected_distfile="${pkgname}-${version}-${_rev}.source.tar.gz"
expected_source_url="https://librewolf.dev/api/packages/librewolf/generic/librewolf-source/\${version}-\${_rev}/\${pkgname}-\${version}-\${_rev}.source.tar.gz"
[ "$1" = "$expected_source_url" ] || {
  echo "distfile URL template mismatch: expected $expected_source_url, got $1" >&2
  exit 1
}

actual_distfile="${1##*/}"
[ "$actual_distfile" = "$expected_template_distfile" ] || {
  echo "distfile basename mismatch: expected $expected_template_distfile, got $actual_distfile" >&2
  exit 1
}

case "$expected_distfile" in
  librewolf-[0-9.]*-[0-9]*.source.tar.gz) ;;
  *) echo "resolved LibreWolf distfile name is invalid: $expected_distfile" >&2; exit 1 ;;
esac

distfile="$expected_distfile"
release_tag="${version}-${_rev}"
# Keep upstream source tags recognizable for revision 1. Packaging-only revisions
# get their own immutable release tag instead of replacing older artifacts.
if [ "$revision" -gt 1 ]; then
  release_tag+="-r${revision}"
fi

if [ -n "$GITHUB_OUTPUT" ]; then
  {
    echo "sha256=$checksum"
    echo "distfile=$distfile"
    echo "version=$version"
    echo "rev=$_rev"
    echo "release_tag=$release_tag"
  } >> "$GITHUB_OUTPUT"
fi

printf 'validated: %s %s (source %s)\n' "$pkgname" "$release_tag" "$distfile"
