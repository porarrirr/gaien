#!/bin/sh

set -eu

template_plist="${PROJECT_DIR}/${BUILD_VERSION_INFO_PLIST_TEMPLATE}"
info_plist="${DERIVED_FILE_DIR}/VersionedInfo.plist"

if [ ! -f "$template_plist" ]; then
    echo "Build versioning failed: Info.plist template was not found at $template_plist" >&2
    exit 1
fi

build_epoch="${BUILD_VERSION_EPOCH:-}"
if [ -z "$build_epoch" ]; then
    if [ ! -f "${CLANG_MODULES_BUILD_SESSION_FILE:-}" ]; then
        echo "Build versioning failed: Xcode build session file is unavailable" >&2
        exit 1
    fi
    build_epoch="$(stat -f %m "$CLANG_MODULES_BUILD_SESSION_FILE")"
fi

case "$build_epoch" in
    ''|*[!0-9]*)
        echo "Build versioning failed: invalid build epoch '$build_epoch'" >&2
        exit 1
        ;;
esac

# All app and extension targets derive their version from the same Xcode build
# session timestamp, even when a parallel build crosses a minute boundary.
build_date="${BUILD_DATE_VERSION:-$(TZ=Asia/Tokyo date -r "$build_epoch" +%Y.%m.%d)}"
build_time="${BUILD_TIME_VERSION:-$(TZ=Asia/Tokyo date -r "$build_epoch" +%H.%M)}"

case "$build_date" in
    [0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]) ;;
    *)
        echo "Build versioning failed: invalid date version '$build_date'" >&2
        exit 1
        ;;
esac

case "$build_time" in
    [0-9][0-9].[0-9][0-9]) ;;
    *)
        echo "Build versioning failed: invalid time version '$build_time'" >&2
        exit 1
        ;;
esac

cp "$template_plist" "$info_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $build_date" "$info_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_time" "$info_plist"

echo "Set $TARGET_NAME version to $build_date ($build_time)"
