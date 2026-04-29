#!/bin/bash

ADD_MODS() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"

    if [ "$USE_MODS" == "Yes" ]; then

        echo "- Adding Mods..."
            if [ ! -d "$EXTRACTED_FIRM_DIR/product/priv-app/AiWallpaper" ]; then
                mkdir -p "$EXTRACTED_FIRM_DIR/product/priv-app/AiWallpaper"
                cp -rfa "$(pwd)/LumiROM/Mods/Apps/AiWallpaper/"* "$EXTRACTED_FIRM_DIR/product/priv-app/AiWallpaper/"
            fi

            if [ ! -d "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull" ]; then
                rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/ailasso"
                rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/ailassomatting"
                rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/inpainting"
                rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/objectremoval"
                rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/reflectionremoval"
                rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/shadowremoval"
                rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/style_transfer"
                rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app"/PhotoEditor_*
                cp -rfa "$(pwd)/LumiROM/Mods/Apps/PhotoEditor_AIFull/"* "$EXTRACTED_FIRM_DIR/system/system/"
                unzip -o "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull.zip" -d "$EXTRACTED_FIRM_DIR/system/system/priv-app/" >/dev/null 2>&1
                rm -f "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull.zip"
            fi

            # For every new mod, add it with all route, until I remake the script
            sudo cp -rfa "$(pwd)/LumiROM/Mods/Files/system/system/bin/"* "$EXTRACTED_FIRM_DIR/system/system/bin/"
            sudo cp -rfa "$(pwd)/LumiROM/Mods/Files/system/system/etc/"* "$EXTRACTED_FIRM_DIR/system/system/etc/"
            sudo cp -rfa "$(pwd)/LumiROM/Mods/vulkan_fix/system/system/lib64/"* "$EXTRACTED_FIRM_DIR/system/system/lib64/"
            sudo cp -rfa "$(pwd)/LumiROM/Mods/volte_fix/vendor/lib64/"* "$EXTRACTED_FIRM_DIR/vendor/lib64/"
            sudo cp -rfa "$(pwd)/LumiROM/Mods/tweaks/system/system/etc/init/"* "$EXTRACTED_FIRM_DIR/system/system/etc/init/"
            sudo cp -rfa "$(pwd)/LumiROM/Mods/wallpaper/system/system/priv-app/wallpaper-res/"* "$EXTRACTED_FIRM_DIR/system/system/priv-app/wallpaper-res/"
        echo " - Mods added"
    else
        echo "The use of mods for this build have been disabled by the user"
    fi

}