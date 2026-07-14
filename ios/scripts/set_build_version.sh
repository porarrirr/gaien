#!/bin/sh

set -eu

template_plist="${PROJECT_DIR}/${BUILD_VERSION_INFO_PLIST_TEMPLATE}"
info_plist="${DERIVED_FILE_DIR}/VersionedInfo.plist"

if [ ! -f "$template_plist" ]; then
    echo "Build versioning failed: Info.plist template was not found at $template_plist" >&2
    exit 1
fi

build_date="${BUILD_DATE_VERSION:-$(TZ=Asia/Tokyo date +%Y.%m.%d)}"
build_time="${BUILD_TIME_VERSION:-$(TZ=Asia/Tokyo date +%H.%M)}"

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
