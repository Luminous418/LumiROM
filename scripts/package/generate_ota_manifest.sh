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

# Builds the "maintainer" block shared by both the ROM and OTA manifests.
_BUILD_MAINTAINER_JSON() {
    local DEVICE="$1"
    jq -n \
        --arg rom_name "$ROM_NAME" \
        --arg name "$MAINTAINER_NAME" \
        --arg handle "$MAINTAINER_HANDLE" \
        --arg device "$(GET_DEVICE_DISPLAY_NAME "$DEVICE")" \
        --arg codename "$DEVICE" \
        --arg avatar "$MAINTAINER_AVATAR" \
        --arg telegram "$MAINTAINER_TELEGRAM" \
        --arg donate "$MAINTAINER_DONATE" \
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
            }
        }'
}

# Builds a single "release" entry from a flashable ZIP (full or incremental).
# The ZIP must contain a build_info.txt with the standard key=value fields.
_BUILD_RELEASE_JSON() {
    local ZIP_PATH="$1"
    local DOWNLOAD_URL="$2"
    local CHANGELOG="$3"

    local BUILD_INFO
    BUILD_INFO="$(unzip -p "$ZIP_PATH" "build_info.txt")" || return 1

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
    FILE_NAME="$(basename "$ZIP_PATH")"
    FILE_SIZE="$(stat -c "%s" "$ZIP_PATH")"
    FILE_SHA256="$(sha256sum "$ZIP_PATH" | cut -d " " -f 1)"

    jq -n \
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
        }'
}

# Builds the full-ROM manifest (updater/{device}.json in the cloudy repo).
# New releases are prepended to the existing history, newest first.
# Usage: GENERATE_OTA_MANIFEST <ROM_ZIP> <DOWNLOAD_URL> <CHANGELOG> [EXISTING_JSON]
GENERATE_OTA_MANIFEST() {
    if [ "$#" -lt 3 ]; then
        echo "Usage: ${FUNCNAME[0]} <ROM_ZIP> <DOWNLOAD_URL> <CHANGELOG> [EXISTING_JSON]" >&2
        echo "       CHANGELOG entries are separated by ;" >&2
        echo "       Outputs the full-ROM manifest JSON to stdout" >&2
        return 1
    fi

    local ROM_ZIP="$1"
    local DOWNLOAD_URL="$2"
    local CHANGELOG="$3"
    local EXISTING_JSON="$4"

    if [ ! -f "$ROM_ZIP" ]; then
        echo "${RED}Error:${RESET} ROM zip not found: $ROM_ZIP" >&2
        return 1
    fi

    local RELEASE
    RELEASE="$(_BUILD_RELEASE_JSON "$ROM_ZIP" "$DOWNLOAD_URL" "$CHANGELOG")" || {
        echo "${RED}Error:${RESET} build_info.txt not found inside $ROM_ZIP" >&2
        return 1
    }

    local DEVICE
    DEVICE="$(grep "^device=" <<< "$(unzip -p "$ROM_ZIP" "build_info.txt")" | cut -d "=" -f 2-)"

    local BASE
    BASE="$(_BUILD_MAINTAINER_JSON "$DEVICE")"

    if [ -n "$EXISTING_JSON" ] && jq -e ".releases" "$EXISTING_JSON" >/dev/null 2>&1; then
        jq --argjson release "$RELEASE" '.releases = [$release] + .releases' "$EXISTING_JSON"
    else
        jq -n --argjson base "$BASE" --argjson release "$RELEASE" \
            '$base + { releases: [$release] }'
    fi
}

# Builds the OTA-only manifest (updater/ota/{device}.json in the cloudy repo).
# This manifest is replaced on every build: it always points to the newest
# incremental package only.
# Usage: GENERATE_OTA_INCREMENTAL_MANIFEST <INC_ZIP> <INC_URL> <CHANGELOG>
GENERATE_OTA_INCREMENTAL_MANIFEST() {
    if [ "$#" -lt 3 ]; then
        echo "Usage: ${FUNCNAME[0]} <INCREMENTAL_ZIP> <INCREMENTAL_URL> <CHANGELOG>" >&2
        echo "       CHANGELOG entries are separated by ;" >&2
        echo "       Outputs the OTA-only manifest JSON to stdout" >&2
        return 1
    fi

    local INC_ZIP="$1"
    local INC_URL="$2"
    local CHANGELOG="$3"

    if [ ! -f "$INC_ZIP" ]; then
        echo "${RED}Error:${RESET} Incremental OTA zip not found: $INC_ZIP" >&2
        return 1
    fi

    local RELEASE BASE DEVICE
    RELEASE="$(_BUILD_RELEASE_JSON "$INC_ZIP" "$INC_URL" "$CHANGELOG")" || {
        echo "${RED}Error:${RESET} build_info.txt not found inside $INC_ZIP" >&2
        return 1
    }
    DEVICE="$(grep "^device=" <<< "$(unzip -p "$INC_ZIP" "build_info.txt")" | cut -d "=" -f 2-)"
    BASE="$(_BUILD_MAINTAINER_JSON "$DEVICE")"

    jq -n --argjson base "$BASE" --argjson release "$RELEASE" \
        '$base + { releases: [$release] }'
}
