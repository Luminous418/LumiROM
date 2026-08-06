#!/bin/bash

source scripts/bash_colors.sh

ADD_MODS() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
    local UPDATER_DIR="./LumiROM/Mods/Updater"

    if [ "$USE_MODS" = "true" ]; then
        # For every new mod, add it with all route, until I remake the script
        echo "${BLUE}============ Mods Installation ============${RESET}"
        
        echo "${YELLOW} - Adding misc system files${RESET}"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/Files/system/system/bin/"* "$EXTRACTED_FIRM_DIR/system/system/bin/"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/Files/system/system/etc/"* "$EXTRACTED_FIRM_DIR/system/system/etc/"

        echo "${YELLOW} - Adding vulkan fix${RESET}"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/vulkan_fix/system/system/lib64/"* "$EXTRACTED_FIRM_DIR/system/system/lib64/"

        echo "${YELLOW} - Adding volte fix${RESET}"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/volte_fix/vendor/lib64/"* "$EXTRACTED_FIRM_DIR/vendor/lib64/"

        echo "${YELLOW} - Adding init tweaks${RESET}"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/tweaks/system/system/etc/init/"* "$EXTRACTED_FIRM_DIR/system/system/etc/init/"

        echo "${YELLOW} - Adding custom wallpapers${RESET}"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/wallpaper/system/system/priv-app/wallpaper-res/"* "$EXTRACTED_FIRM_DIR/system/system/priv-app/wallpaper-res/"

        echo "${YELLOW} - Adding rom updater${RESET}"
        mkdir -p "$UPDATER_DIR/system/system/priv-app/Cloudy/"
        mkdir -p "$EXTRACTED_FIRM_DIR/system/system/priv-app/Cloudy/"

        if [ ! -f "$UPDATER_DIR/system/system/priv-app/Cloudy/Cloudy.apk" ]; then
            aria2c -x 1 -d "$UPDATER_DIR/system/system/priv-app/Cloudy/" -o "Cloudy.apk" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://github.com/Luminous418/cloudy-app/releases/download/cloudy-1.0/app-release.apk" || return 1
        fi

        cp -rfa "$UPDATER_DIR/system/system/priv-app/Cloudy/"* "$EXTRACTED_FIRM_DIR/system/system/priv-app/Cloudy/"
        
        # Cleanup any leftover .aria2 control files
        wait
        find "$UPDATER_DIR/system/system/priv-app/Cloudy/" -name "*.aria2" -exec rm -f {} +
        
        echo "${GREEN} - Mods added${RESET}"
    else
        echo "${RED}The use of mods for this build have been disabled by the user${RESET}"
    fi

}