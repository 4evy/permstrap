#!/usr/bin/env bash
# shellcheck shell=bash

set -eu

source_root=$1
allowlist=$2
actual=$(mktemp "${TMPDIR:-/tmp}/permstrap-objc-actual.XXXXXX")
expected=$(mktemp "${TMPDIR:-/tmp}/permstrap-objc-expected.XXXXXX")
trap 'rm -f "$actual" "$expected"' EXIT HUP INT TERM

LC_ALL=C find "$source_root/src" -type f -name '*.m' -print |
	sed "s#^$source_root/##" |
	sort >"$actual"
LC_ALL=C sed \
	-e '/^[[:space:]]*#/d' \
	-e '/^[[:space:]]*$/d' \
	"$allowlist" |
	sort >"$expected"

if ! diff -u "$expected" "$actual"; then
	echo "Objective-C boundary changed; update the implementation or its reviewed allowlist and ledger." >&2
	exit 1
fi
