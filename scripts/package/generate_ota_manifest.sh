#!/bin/bash

source scripts/utils/bash_colors.sh

ROM_NAME="${ROM_NAME:-LumiROM}"
MAINTAINER_NAME="${MAINTAINER_NAME:-Lumi}"
MAINTAINER_HANDLE="${MAINTAINER_HANDLE:-@Luminous418}"
MAINTAINER_AVATAR="${MAINTAINER_AVATAR:-https://avatars.githubusercontent.com/u/107070993?v=4}"
MAINTAINER_TELEGRAM="${MAINTAINER_TELEGRAM:-https://t.me/LumiROMs}"
MAINTAINER_DONATE="${MAINTAINER_DONATE:-https://buymeacoffee.com/luminous418}"

GET_DEVICE_DISPLAY_NAME() {
    case "$1" in
        a32|a32m) echo "Samsung Galaxy A32 4G" ;;
        a22) echo "Samsung Galaxy A22 4G" ;;
        a22x) echo "Samsung Galaxy A22 5G" ;;
        m32) echo "Samsung Galaxy M32 4G" ;;
        f22) echo "Samsung Galaxy F22 4G" ;;
        *) echo "Samsung Galaxy Device" ;;
    esac
}

GENERATE_OTA_MANIFEST() {
    if [ "$#" -lt 3 ]; then
        echo "Usage: ${FUNCNAME[0]} <ROM_ZIP> <DOWNLOAD_URL> <CHANGELOG> [EXISTING_JSON] [INCREMENTAL_ZIP] [INCREMENTAL_URL]" >&2
        echo "       CHANGELOG entries are separated by ;" >&2
        echo "       Outputs the manifest JSON to stdout" >&2
        return 1
    fi

    local ROM_ZIP="$1"
    local DOWNLOAD_URL="$2"
    local CHANGELOG="$3"
    local EXISTING_JSON="$4"
    local INCREMENTAL_ZIP="$5"
    local INCREMENTAL_URL="$6"

    if [ ! -f "$ROM_ZIP" ]; then
        echo "${RED}Error:${RESET} ROM zip not found: $ROM_ZIP" >&2
        return 1
    fi

    local BUILD_INFO
    BUILD_INFO="$(unzip -p "$ROM_ZIP" "build_info.txt")" || {
        echo "${RED}Error:${RESET} build_info.txt not found inside $ROM_ZIP" >&2
        return 1
    }

    local DEVICE VERSION VERSION_CODE BUILD_DATE ANDROID_VERSION ONEUI_VERSION
    local SECURITY_PATCH FINGERPRINT DEVICE_MODEL KERNEL_VERSION PARTITION_LAYOUT

    DEVICE="$(grep "^device=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"
    VERSION="$(grep "^version=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"
    VERSION_CODE="$(grep "^version_code=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"
    BUILD_DATE="$(grep "^build_date=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"
    ANDROID_VERSION="$(grep "^android_version=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"
    ONEUI_VERSION="$(grep "^oneui_version=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"
    SECURITY_PATCH="$(grep "^security_patch=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"
    FINGERPRINT="$(grep "^build_fingerprint=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"
    DEVICE_MODEL="$(grep "^device_model=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"
    KERNEL_VERSION="$(grep "^kernel_version=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"
    PARTITION_LAYOUT="$(grep "^partition_layout=" <<< "$BUILD_INFO" | cut -d "=" -f 2-)"

    local FILE_NAME FILE_SIZE FILE_SHA256
    FILE_NAME="$(basename "$ROM_ZIP")"
    FILE_SIZE="$(stat -c "%s" "$ROM_ZIP")"
    FILE_SHA256="$(sha256sum "$ROM_ZIP" | cut -d " " -f 1)"

    local RELEASE
    RELEASE="$(jq -n \
        --arg version "$VERSION" \
        --arg version_code "$VERSION_CODE" \
        --arg build_date "$BUILD_DATE" \
        --arg android_version "$ANDROID_VERSION" \
        --arg oneui_version "$ONEUI_VERSION" \
        --arg security_patch "$SECURITY_PATCH" \
        --arg fingerprint "$FINGERPRINT" \
        --arg device_model "$DEVICE_MODEL" \
        --arg kernel_version "$KERNEL_VERSION" \
        --arg partition_layout "$PARTITION_LAYOUT" \
        --arg changelog "$CHANGELOG" \
        --arg url "$DOWNLOAD_URL" \
        --arg filename "$FILE_NAME" \
        --arg size "$FILE_SIZE" \
        --arg sha256 "$FILE_SHA256" \
        '{
            version: $version,
            version_code: ($version_code | if length > 0 then tonumber else null end),
            build_date: $build_date,
            android_version: $android_version,
            oneui_version: $oneui_version,
            security_patch: $security_patch,
            build_fingerprint: $fingerprint,
            device_model: $device_model,
            kernel_version: $kernel_version,
            partition_layout: $partition_layout,
            changelog: ($changelog | split(";") | map(select(length > 0))),
            download: {
                url: $url,
                filename: $filename,
                size_bytes: ($size | tonumber),
                sha256: $sha256,
                install_type: "recovery_zip"
            }
        }')"

    if [ -n "$INCREMENTAL_ZIP" ] && [ -f "$INCREMENTAL_ZIP" ]; then
        local INC_INFO INC_FROM INC_NAME INC_SIZE INC_SHA256
        INC_INFO="$(unzip -p "$INCREMENTAL_ZIP" "build_info.txt" 2>/dev/null)" || INC_INFO=""
        INC_FROM="$(grep "^incremental_from=" <<< "$INC_INFO" | cut -d "=" -f 2-)"
        INC_NAME="$(basename "$INCREMENTAL_ZIP")"
        INC_SIZE="$(stat -c "%s" "$INCREMENTAL_ZIP")"
        INC_SHA256="$(sha256sum "$INCREMENTAL_ZIP" | cut -d " " -f 1)"

        if [ -n "$INC_FROM" ]; then
            RELEASE="$(jq -n \
                --argjson release "$RELEASE" \
                --arg url "$INCREMENTAL_URL" \
                --arg filename "$INC_NAME" \
                --arg size "$INC_SIZE" \
                --arg sha256 "$INC_SHA256" \
                --arg from "$INC_FROM" \
                '$release + {
                    download_incremental: {
                        url: $url,
                        filename: $filename,
                        size_bytes: ($size | tonumber),
                        sha256: $sha256,
                        install_type: "recovery_zip",
                        incremental_from: $from
                    }
                }')"
        fi
    fi

    if [ -n "$EXISTING_JSON" ] && jq -e ".releases" "$EXISTING_JSON" >/dev/null 2>&1; then
        jq --argjson release "$RELEASE" '.releases = [$release] + .releases' "$EXISTING_JSON"
    else
        jq -n \
            --arg rom_name "$ROM_NAME" \
            --arg name "$MAINTAINER_NAME" \
            --arg handle "$MAINTAINER_HANDLE" \
            --arg device "$(GET_DEVICE_DISPLAY_NAME "$DEVICE")" \
            --arg codename "$DEVICE" \
            --arg avatar "$MAINTAINER_AVATAR" \
            --arg telegram "$MAINTAINER_TELEGRAM" \
            --arg donate "$MAINTAINER_DONATE" \
            --argjson release "$RELEASE" \
            '{
                rom_name: $rom_name,
                maintainer: {
                    name: $name,
                    handle: $handle,
                    device: $device,
                    codename: $codename,
                    avatar_url: $avatar,
                    telegram: $telegram,
                    donate_url: $donate
                },
                releases: [$release]
            }'
    fi
}
