#!/bin/bash

source scripts/bash_colors.sh

IS_OFFICIAL() {
    CURRENT_SIGNATURE=$(printf "%s" "$LUMIROM_BUILD" | sha256sum | cut -d ' ' -f 1)

    if [ "$CURRENT_SIGNATURE" == "$OFFICIAL_HASH" ]; then
        export BUILD_STATUS="OFFICIAL"
        export ROM_TAG="✨ LumiROM Official Build"
        echo "BUILD_STATUS=OFFICIAL" >> "$GITHUB_ENV"
        echo "ROM_TAG=✨ LumiROM Official Build" >> "$GITHUB_ENV"
    else
        export BUILD_STATUS="UNOFFICIAL"
        export ROM_TAG="🛠️ LumiROM Unofficial Build"
        echo "BUILD_STATUS=UNOFFICIAL" >> "$GITHUB_ENV"
        echo "ROM_TAG=🛠️ LumiROM Unofficial Build" >> "$GITHUB_ENV"
    fi

    echo "${BLUE}--- $ROM_TAG detected ---${RESET}"
}

CHECK_FILE() {
    if [ ! -f "$1" ]; then
        echo "${RED}[!] File not found:${RESET} $1"
        echo "- Skipping..."
        return 1
    fi
    return 0
}

REMOVE_LINE() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <TARGET_LINE> <TARGET_FILE>"
        return 1
    fi

    local LINE="$1"
    local FILE="$2"

    echo "${YELLOW}Deleting${RESET} $LINE ${YELLOW}from${RESET} $FILE"
    grep -vxF "$LINE" "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
}

DISABLE_FBE() {
    local EXTRACTED_FIRM_DIR="$1"

    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

    local i

    for i in "$EXTRACTED_FIRM_DIR"/vendor/etc/fstab.mt*; do
        if [ -f "$i" ]; then
            echo "${YELLOW}Disabling full-disk encryption (FBE) for /data...${RESET}"
            echo "- Found $i."

            # حذف inlinecrypt من mount options
            sed -i 's/,inlinecrypt//g' "$i"
            sed -i 's/inlinecrypt,//g' "$i"

            # حذف fileencryption=... من fs_mgr flags
            sed -i 's/fileencryption=[^,[:space:]]*//' "$i"

            # تنظيف أي فاصلة مزدوجة متبقية
            sed -i 's/,,/,/g' "$i"

            echo "${GREEN}[+] FBE disabled on $i${RESET}"
        fi
    done
}
# ============================================================
# GET VNDK VERSION
# Auto detect VNDK from firmware
# Supports:
#   system/etc/vintf/manifest.xml
#   apex/com.android.vndk.vXX
#   vndk-vXX directories
# No fixed A31/A32 values
# ============================================================
GET_VNDK_VERSION() {
    local FIRMWARE_DIR="$1"

    if [ -z "$FIRMWARE_DIR" ]; then
        echo "0"
        return 1
    fi

    echo "${YELLOW}[*] Searching VNDK version in $FIRMWARE_DIR${RESET}" >&2

    # 1) Search manifest.xml anywhere
    local MANIFEST
    MANIFEST=$(find "$FIRMWARE_DIR" -type f -name "manifest.xml" 2>/dev/null | grep "vintf" | head -1)

    if [ -n "$MANIFEST" ] && [ -f "$MANIFEST" ]; then
        local VNDK
        VNDK=$(grep -oP '(?<=targetVndkVersion>)[^<]+' "$MANIFEST" | head -1)

        if [ -n "$VNDK" ]; then
            echo "${GREEN}[+] Found VNDK $VNDK from $MANIFEST${RESET}" >&2
            echo "$VNDK"
            return 0
        fi
    fi


    # 2) Search apex VNDK
    local APEX_VNDK
    APEX_VNDK=$(find "$FIRMWARE_DIR" \
        -type d \
        -name "com.android.vndk.v*" 2>/dev/null \
        | grep -oP 'v[0-9]+' \
        | head -1 \
        | tr -d 'v')

    if [ -n "$APEX_VNDK" ]; then
        echo "${GREEN}[+] Found APEX VNDK $APEX_VNDK${RESET}" >&2
        echo "$APEX_VNDK"
        return 0
    fi


    # 3) Search normal vndk folders
    local DIR_VNDK
    DIR_VNDK=$(find "$FIRMWARE_DIR" \
        -type d \
        \( -name "vndk-v*" -o -name "vndk-*" \) 2>/dev/null \
        | grep -oP 'vndk[-_]v?\K[0-9]+' \
        | head -1)

    if [ -n "$DIR_VNDK" ]; then
        echo "${GREEN}[+] Found folder VNDK $DIR_VNDK${RESET}" >&2
        echo "$DIR_VNDK"
        return 0
    fi


    echo "${RED}[!] VNDK version not detected${RESET}" >&2
    echo "0"
}
