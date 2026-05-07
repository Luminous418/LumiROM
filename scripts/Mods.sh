#!/bin/bash

source scripts/bash_colors.sh

ADD_MODS() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"

    if [ "$USE_MODS" == "Yes" ]; then
        # For every new mod, add it with all route, until I remake the script
        echo -e "${BLUE}============ Mods Installation ============${RESET}"
        
        echo -e "${YELLOW} - Adding misc system files${RESET}"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/Files/system/system/bin/"* "$EXTRACTED_FIRM_DIR/system/system/bin/"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/Files/system/system/etc/"* "$EXTRACTED_FIRM_DIR/system/system/etc/"

        echo -e "${YELLOW} - Adding vulkan fix${RESET}"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/vulkan_fix/system/system/lib64/"* "$EXTRACTED_FIRM_DIR/system/system/lib64/"

        echo -e "${YELLOW} - Adding volte fix${RESET}"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/volte_fix/vendor/lib64/"* "$EXTRACTED_FIRM_DIR/vendor/lib64/"

        echo -e "${YELLOW} - Adding init tweaks${RESET}"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/tweaks/system/system/etc/init/"* "$EXTRACTED_FIRM_DIR/system/system/etc/init/"

        echo -e "${YELLOW} - Adding custom wallpapers${RESET}"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/wallpaper/system/system/priv-app/wallpaper-res/"* "$EXTRACTED_FIRM_DIR/system/system/priv-app/wallpaper-res/"
        
        echo -e "${GREEN} - Mods added${RESET}"
    else
        echo -e "${RED}The use of mods for this build have been disabled by the user${RESET}"
    fi

}