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
# FIX: VNDK detection بدون crash لو manifest.xml مو موجود
# A325F = VNDK 31 / A315F = VNDK 30
# ============================================================
GET_VNDK_VERSION() {
    local FIRMWARE_DIR="$1"
    local MANIFEST_PATH="$FIRMWARE_DIR/system/system/system_ext/etc/vintf/manifest.xml"
    local FALLBACK_VERSION="${2:-31}"

    if [ -f "$MANIFEST_PATH" ]; then
        local DETECTED
        DETECTED=$(grep -oP '(?<=targetVndkVersion>)[^<]+' "$MANIFEST_PATH" | head -1)
        if [ -n "$DETECTED" ]; then
            echo "$DETECTED"
            return 0
        fi
    fi

    echo "${YELLOW}[!] manifest.xml not found — using fallback VNDK: $FALLBACK_VERSION${RESET}" >&2
    echo "$FALLBACK_VERSION"
}

FIX_SEPOLICY_VERS() {
    local VENDOR_DIR="$1"
    local TARGET_VERSION="${2:-30.0}"
    local VERS_FILE="$VENDOR_DIR/etc/selinux/plat_sepolicy_vers.txt"

    if [ -f "$VERS_FILE" ]; then
        local CURRENT
        CURRENT=$(cat "$VERS_FILE")
        echo "${YELLOW}[*] plat_sepolicy_vers.txt: $CURRENT → $TARGET_VERSION${RESET}"
        echo "$TARGET_VERSION" > "$VERS_FILE"
        echo "${GREEN}[+] Fixed sepolicy version${RESET}"
    else
        echo "${RED}[!] plat_sepolicy_vers.txt not found at $VERS_FILE${RESET}"
    fi
}
