#!/bin/bash

export LC_ALL=C

source scripts/utils/bash_colors.sh
source scripts/utils/platform_key.sh


PATCH_SECSETTINGS() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <DECOMPILED_SECSETTINGS_DIR>"
        echo "  Applies the SecSettings patches (Cloudy entry + ROM logo)."
        return 1
    fi

    local SECSETTINGS_DIR="$1"

    if [ ! -d "$SECSETTINGS_DIR" ]; then
        echo "${RED}SecSettings decompiled directory not found: $SECSETTINGS_DIR${RESET}"
        return 1
    fi

    local PATCHES=(
        "0002-Open-Cloudy-from-Software-update-in-settings.patch"
        "0003-Add-LumiROM-Logo.patch"
    )

    for PATCH in "${PATCHES[@]}"; do
        local PATCH_FILE="$(pwd)/scripts/patches/$PATCH"
        if [ ! -f "$PATCH_FILE" ]; then
            echo "${RED}Patch not found: $PATCH_FILE${RESET}"
            return 1
        fi
        echo "${YELLOW}Applying SecSettings patch: $PATCH${RESET}"
        if ! patch -p1 -d "$SECSETTINGS_DIR" < "$PATCH_FILE" >/dev/null 2>&1; then
            echo "${RED}Failed to apply $PATCH${RESET}"
            return 1
        fi
    done

    # Copy the ROM logo into the decompiled SecSettings tree.
    local LOGO_SRC="$(pwd)/LumiROM/Mods/SecSettings/res/drawable/logo.png"
    if [ -f "$LOGO_SRC" ]; then
        mkdir -p "$SECSETTINGS_DIR/res/drawable"
        cp -f "$LOGO_SRC" "$SECSETTINGS_DIR/res/drawable/logo.png"
        echo "${GREEN}ROM logo copied into SecSettings.${RESET}"
    else
        echo "${RED}ROM logo not found: $LOGO_SRC${RESET}"
        return 1
    fi

    echo "${GREEN}SecSettings patched.${RESET}"
}


REBUILD_AND_SIGN_APK() {
    echo ""
    if [ "$#" -ne 4 ]; then
        echo "Usage: ${FUNCNAME[0]} <APKTOOL> <DECOMPILED_DIR> <FRAMEWORK_DIR> <OUT_APK>"
        echo "  Recompiles a decompiled APK, zipaligns and re-signs it with"
        echo "  the active platform key."
        return 1
    fi

    local APKTOOL="$1"
    local DECOMPILED_DIR="$2"
    local FRAMEWORK_DIR="$3"
    local OUT_APK="$4"

    if [ ! -d "$DECOMPILED_DIR" ]; then
        echo "${RED}Decompiled directory not found: $DECOMPILED_DIR${RESET}"
        return 1
    fi

    echo "${YELLOW}Recompiling:${RESET} $DECOMPILED_DIR"
    java -jar "$APKTOOL" b "$DECOMPILED_DIR" --copy-original -p "$FRAMEWORK_DIR" -o "$OUT_APK" || {
        echo "${RED}Failed to recompile $DECOMPILED_DIR${RESET}"
        return 1
    }

    local ALIGNED="${OUT_APK%.apk}.aligned.apk"
    zipalign -f 4 "$OUT_APK" "$ALIGNED" || return 1
    rm -f "$OUT_APK"

    local KEY_DIR
    KEY_DIR="$(GET_ACTIVE_KEY_FILES)"
    echo "${YELLOW}Re-signing with platform key from $KEY_DIR${RESET}"
    apksigner sign --key "$KEY_DIR/platform.pk8" --cert "$KEY_DIR/platform.x509.pem" \
        --out "$OUT_APK" "$ALIGNED" || return 1
    rm -f "$ALIGNED"

    echo "${GREEN}Rebuilt and signed: $OUT_APK${RESET}"
}


PATCH_SETUPWIZARD() {
    echo ""
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <DECOMPILED_SETUPWIZARD_DIR> [LOGO_PNG]"
        echo "  Applies the SetupWizard patches (LumiROM disclaimer + navbar step)."
        return 1
    fi

    local SW_DIR="$1"
    local LOGO_SRC="${2:-$(pwd)/LumiROM/Mods/SecSettings/res/drawable/logo.png}"

    if [ ! -d "$SW_DIR" ]; then
        echo "${RED}SetupWizard decompiled directory not found: $SW_DIR${RESET}"
        return 1
    fi

    # Copy the banner logo into the decompiled tree (binary, not part of the patches).
    mkdir -p "$SW_DIR/res/drawable-xxhdpi"
    if [ -f "$LOGO_SRC" ]; then
        cp -f "$LOGO_SRC" "$SW_DIR/res/drawable-xxhdpi/lumirom_logo.png"
        echo "${GREEN}LumiROM banner logo copied into SetupWizard.${RESET}"
    else
        echo "${YELLOW}  [!] Logo not found: $LOGO_SRC${RESET}"
    fi

    local PATCHES=(
        "0004-Add-LumiROM-Disclaimer.patch"
        "0005-Add-LumiROM-Disclaimer-Strings.patch"
        "0006-SetupWizard-Steps.patch"
    )

    for PATCH in "${PATCHES[@]}"; do
        local PATCH_FILE="$(pwd)/scripts/patches/$PATCH"
        if [ ! -f "$PATCH_FILE" ]; then
            echo "${RED}Patch not found: $PATCH_FILE${RESET}"
            return 1
        fi
        echo "${YELLOW}Applying SetupWizard patch: $PATCH${RESET}"
        if ! patch -p1 -d "$SW_DIR" < "$PATCH_FILE" >/dev/null 2>&1; then
            echo "${RED}Failed to apply $PATCH${RESET}"
            return 1
        fi
    done

    echo "${GREEN}SetupWizard patched.${RESET}"
}
