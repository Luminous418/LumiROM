#!/bin/bash

source scripts/utils/bash_colors.sh

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