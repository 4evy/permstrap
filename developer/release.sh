#!/usr/bin/env bash
# shellcheck shell=bash

set -eu

export LC_ALL=C

fail() {
	printf 'release: %s\n' "$1" >&2
	exit 1
}

script_directory=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
source_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)
release_directory="$source_root/release"
release_application="$release_directory/Permstrap.app"

assert_release_directory_contents() {
	for entry in \
		"$release_directory"/* \
		"$release_directory"/.[!.]* \
		"$release_directory"/..?*; do
		if ! test -e "$entry" && ! test -L "$entry"; then
			continue
		fi
		test "$entry" = "$release_application" ||
			fail "release directory contains an unexpected entry: $entry"
	done
}

test "$(uname -s)" = Darwin ||
	fail 'the production application can only be built on macOS'
test "$(uname -m)" = arm64 ||
	fail 'the production application must be built natively on arm64'

mkdir -p "$release_directory"
/bin/rm -f "$release_directory/.DS_Store"
assert_release_directory_contents

temporary_root=$(mktemp -d "${TMPDIR:-/tmp}/permstrap-release.XXXXXX")
build_directory="$temporary_root/build"
staged_application="$temporary_root/Permstrap.app"
staged_executable="$staged_application/Contents/MacOS/permstrap"
dependencies_file="$temporary_root/dynamic-dependencies.txt"
trap 'rm -rf "$temporary_root"' EXIT HUP INT TERM

cd "$source_root"
meson setup "$build_directory" \
	-Dbuildtype=release \
	-Doptimization=3 \
	-Ddebug=false \
	-Ddefault_library=static \
	-Dprefer_static=false \
	-Dstrip=true \
	-Db_lto=true \
	-Db_lto_mode=thin \
	-Db_ndebug=true \
	-Db_pie=true \
	-Db_staticpic=true \
	-Db_asneeded=true \
	-Db_lundef=true \
	-Ddeveloper_checks=disabled

release_configuration=$(meson configure "$build_directory")
assert_release_option() {
	option_name=$1
	expected_value=$2
	if ! printf '%s\n' "$release_configuration" |
		awk -v option="$option_name" -v expected="$expected_value" \
			'$1 == option && $2 == expected { found = 1 } END { exit found ? 0 : 1 }'; then
		fail "Meson option $option_name is not $expected_value"
	fi
}

assert_release_option buildtype release
assert_release_option optimization 3
assert_release_option debug false
assert_release_option default_library static
assert_release_option prefer_static false
assert_release_option strip true
assert_release_option b_lto true
assert_release_option b_lto_mode thin
assert_release_option b_ndebug true
assert_release_option b_pie true
assert_release_option b_staticpic true
assert_release_option b_lundef true
assert_release_option developer_checks disabled

# Only the application and icon dependency graphs are compiled. Tests and the
# standalone probe remain development artifacts and are not part of a release.
meson compile -C "$build_directory" \
	bundle-application-executable \
	application-icon

built_application="$build_directory/Permstrap.app"
test -x "$built_application/Contents/MacOS/permstrap" ||
	fail 'Meson did not produce the application executable'

/usr/bin/ditto --noqtn "$built_application" "$staged_application"
/bin/rm -f \
	"$staged_application/Contents/Resources/AppIcon.partial.plist"
/usr/bin/strip -S -x "$staged_executable"

codesign_identity=${CODESIGN_IDENTITY:--}
if test "$codesign_identity" = '-'; then
	/usr/bin/codesign \
		--force \
		--options runtime \
		--sign - \
		"$staged_application"
	signing_description='ad hoc hardened-runtime'
else
	/usr/bin/codesign \
		--force \
		--options runtime \
		--timestamp \
		--sign "$codesign_identity" \
		"$staged_application"
	signing_description=$codesign_identity
fi

info_plist="$staged_application/Contents/Info.plist"
/usr/bin/plutil -lint "$info_plist" >/dev/null
test "$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$info_plist")" = \
	'dev.4evy.permstrap' ||
	fail 'the bundle identifier is not dev.4evy.permstrap'
test "$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$info_plist")" = \
	'permstrap' ||
	fail 'CFBundleExecutable does not name permstrap'
test "$(/usr/bin/plutil -extract LSMinimumSystemVersion raw -o - "$info_plist")" = \
	'26.0' ||
	fail 'the bundle deployment target is not macOS 26.0'

test "$(/usr/bin/lipo -archs "$staged_executable")" = arm64 ||
	fail 'the release executable is not a thin arm64 Mach-O'

build_metadata=$(/usr/bin/xcrun vtool -show-build "$staged_executable")
case "$build_metadata" in
*'platform MACOS'*) ;;
*) fail 'the release executable does not target macOS' ;;
esac
case "$build_metadata" in
*'minos 26.0'*) ;;
*) fail 'the executable deployment target is not macOS 26.0' ;;
esac

if /usr/bin/otool -l "$staged_executable" | grep -q 'cmd LC_RPATH'; then
	fail 'the release executable contains a runtime library search path'
fi
if /usr/bin/otool -l "$staged_executable" | grep -q '__DWARF'; then
	fail 'the release executable still contains debug sections'
fi

/usr/bin/otool -L "$staged_executable" |
	sed '1d' |
	awk '{ print $1 }' >"$dependencies_file"
while IFS= read -r dependency; do
	case "$dependency" in
	/System/Library/Frameworks/* | /usr/lib/*) ;;
	*) fail "non-system dynamic dependency found: $dependency" ;;
	esac
done <"$dependencies_file"

embedded_library=$(
	find "$staged_application" -type f \
		\( -name '*.a' -o -name '*.dylib' -o -name '*.so' \) \
		-print -quit
)
test -z "$embedded_library" ||
	fail "embedded library found in release bundle: $embedded_library"

for required_resource in \
	Permissions.json \
	Permissions.schema.json \
	PermissionTargets.schema.json \
	RuntimePolicy.json \
	RuntimePolicy.schema.json \
	AppIcon.icns \
	Assets.car; do
	test -f "$staged_application/Contents/Resources/$required_resource" ||
		fail "required resource is missing: $required_resource"
done

/usr/bin/codesign --verify --deep --strict --verbose=2 "$staged_application"
signature_details=$(
	/usr/bin/codesign --display --verbose=4 "$staged_application" 2>&1
)
case "$signature_details" in
*'runtime'*) ;;
*) fail 'the code signature does not enable the hardened runtime' ;;
esac

"$staged_executable" --version
"$staged_executable" --self-check

if test -e "$release_application"; then
	/bin/rm -rf "$release_application"
fi
/bin/mv "$staged_application" "$release_application"

/bin/rm -f "$release_directory/.DS_Store"
assert_release_directory_contents

dependency_count=$(wc -l <"$dependencies_file" | tr -d ' ')
application_size=$(du -sh "$release_application" | awk '{ print $1 }')
printf '\nRelease ready: %s\n' "$release_application"
printf '  architecture: arm64\n'
printf '  optimization: O3 + ThinLTO, stripped\n'
printf '  linkage: static project/dependencies; %s Apple system links\n' \
	"$dependency_count"
printf '  signing: %s\n' "$signing_description"
printf '  size: %s\n' "$application_size"
