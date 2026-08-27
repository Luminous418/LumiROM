#!/bin/bash

source scripts/utils/bash_colors.sh

source scripts/utils/platform_key.sh

SIGN_WITH_PLATFORM_KEY() {
    echo "" >&2
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <APK>" >&2
        return 1
    fi

    local APK="$1"
    local KEY_DIR
    local PK8
    local CERT

    if [ ! -f "$APK" ]; then
        echo "${RED}APK not found: $APK${RESET}" >&2
        return 1
    fi

    KEY_DIR="$(GET_ACTIVE_KEY_FILES)"
    PK8="$KEY_DIR/platform.pk8"
    CERT="$KEY_DIR/platform.x509.pem"

    if [ ! -f "$PK8" ] || [ ! -f "$CERT" ]; then
        echo "${RED}Platform key not found in $KEY_DIR${RESET}" >&2
        return 1
    fi

    local OUT="${TMPDIR:-/tmp}/cloudy_signed_$$.apk"

    echo "${YELLOW} - Re-signing $APK with platform key${RESET}" >&2
    if ! apksigner sign --key "$PK8" --cert "$CERT" --out "$OUT" "$APK" 2>/dev/null; then
        echo "${RED} - Failed to sign $APK${RESET}" >&2
        rm -f "$OUT"
        return 1
    fi

    echo "${GREEN} - Signed with platform key${RESET}" >&2
    echo "$OUT"
}

ADD_CLOUDY() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local UPDATER_DIR="./LumiROM/Mods/Cloudy"

    mkdir -p "$UPDATER_DIR/system/system/priv-app/Cloudy/"
    mkdir -p "$UPDATER_DIR/system/system/etc/permissions/"
    mkdir -p "$UPDATER_DIR/system/system/etc/sysconfig/"

    echo "${YELLOW} - Adding Cloudy${RESET}"
    sudo cp -rfa "$UPDATER_DIR/system/system/." "$EXTRACTED_FIRM_DIR/system/system/"
    local SIGNED_APK
    SIGNED_APK="$(SIGN_WITH_PLATFORM_KEY "$UPDATER_DIR/system/system/priv-app/Cloudy/Cloudy.apk")" || return 1
    if [ -n "$SIGNED_APK" ] && [ -f "$SIGNED_APK" ]; then
        sudo cp -f "$SIGNED_APK" "$EXTRACTED_FIRM_DIR/system/system/priv-app/Cloudy/Cloudy.apk"
        rm -f "$SIGNED_APK"
    else
        echo "${RED} - Cloudy not re-signed, keeping stock signature${RESET}"
    fi

    echo "${YELLOW} - Baking Cloudy SELinux rules (system_ext_sepolicy.cil)${RESET}"
    local SELINUX_CIL="$EXTRACTED_FIRM_DIR/system/system_ext/etc/selinux/system_ext_sepolicy.cil"
    if [ -f "$SELINUX_CIL" ]; then
        # Mirrors magisk-module/sepolicy.rule so no Magisk module is required on LumiROM builds.
        # init recompiles the policy from these CILs when they differ from precompiled_sepolicy,
        # so appending here is all that's needed for the baked rules to be enforced.
        cat >> "$SELINUX_CIL" <<'CLOUDY_EOF'
(allow untrusted_app cache_file (dir (search write add_name)))
(allow untrusted_app cache_file (file (create open write getattr setattr)))
(allow untrusted_app block_device (dir (search read)))
(allow untrusted_app block_device (lnk_file (read getattr)))
(allow untrusted_app power_service (service_manager (find)))
(allow untrusted_app system_server (binder (call)))
CLOUDY_EOF
    else
        echo "${RED}Warning: system_ext_sepolicy.cil not found at${RESET} $SELINUX_CIL"
    fi

    echo "${GREEN} - Cloudy OTA helper added${RESET}"
}