#!/bin/bash

source scripts/bash_colors.sh

UPDATE_ZIP_SCRIPT() {
    
        local EXTRACTED_FIRM_DIR="$1"
        BUILD_PROP_PATH="$EXTRACTED_FIRM_DIR/system/system/build.prop"
        FINGERPRINT=$(grep -m 1 "ro.system.build.fingerprint=" "$BUILD_PROP_PATH" | cut -d'=' -f2)
        BUILD_DATE=$(date +'%d%m%Y')
        DEVICE="$STOCK_DEVICE"
        UPDATER_PATH="$(pwd)/template/META-INF/com/google/android/updater-script"

        if [[ "$DEVICE" == "SM-A325F" || "$DEVICE" == "SM-A325M" ]]; then
            DEVICE_CODENAME="a32"
            DISPLAY_NAME="Galaxy A32 4G"
        elif [[ "$DEVICE" == "SM-A225F" ]]; then
            DEVICE_CODENAME="a22"
            DISPLAY_NAME="Galaxy A22 4G"
        elif [[ "$DEVICE" == "SM-A226B" ]]; then
            DEVICE_CODENAME="a22x"
            DISPLAY_NAME="Galaxy A22 5G"
        elif [[ "$DEVICE" == "SM-M325F" ]]; then
            DEVICE_CODENAME="m32"
            DISPLAY_NAME="Galaxy M32 4G"
        elif [[ "$DEVICE" == "SM-E225F" ]]; then
            DEVICE_CODENAME="f22"
            DISPLAY_NAME="Galaxy F22 4G"
        else
            DEVICE_CODENAME="unknown"
            DISPLAY_NAME="Unknown Device"
        fi

        if [ -z "$FINGERPRINT" ]; then
            echo -e "${YELLOW}Warning: Fingerprint not found, using generic value.${RESET}"
            FINGERPRINT="Unknown/Release-Keys"
        fi

        echo -e "${GREEN}Detected Fingerprint:${RESET} $FINGERPRINT"
        sed -i "s!ui_print(\"Source: .*\");!ui_print(\"Source: $FINGERPRINT\");!" "$UPDATER_PATH"
        
        NEW_CHECK="getprop(\"ro.boot.em.model\") == \"$DEVICE\" || abort(\"E3004: This package is for $DEVICE_CODENAME\");"

        echo -e "${GREEN}Updating device on updater-script for${RESET} $DISPLAY_NAME..."
      
        sed -i "s!^getprop(\"ro.boot.em.model\").*!$NEW_CHECK!" "$UPDATER_PATH"

        sed -i "s!ui_print(\".*for .*\");!ui_print(\"   $LUMIROM_VERSION-$BUILD_DATE $BUILD_STATUS for $DISPLAY_NAME\");!" "$UPDATER_PATH"

}

FLASHABLE_ZIP_CREATION() {
    
        BUILD_DATE=$(date +'%d%m%Y')
        TIMESTAMP=$(date +'%s')
        DEVICE="$STOCK_DEVICE"

        if [[ "$DEVICE" == "SM-A325F" ]]; then
            DEVICE_CODENAME="a32"
        elif [[ "$DEVICE" == "SM-A325M" ]]; then
            DEVICE_CODENAME="a32m"
        elif [[ "$DEVICE" == "SM-A225F" ]]; then
            DEVICE_CODENAME="a22"
        elif [[ "$DEVICE" == "SM-A226B" ]]; then
            DEVICE_CODENAME="a22x"
        elif [[ "$DEVICE" == "SM-M325F" ]]; then
            DEVICE_CODENAME="m32"
        elif [[ "$DEVICE" == "SM-E225F" ]]; then
            DEVICE_CODENAME="f22"
        else
            DEVICE_CODENAME="unknown"
        fi

        TEMPLATE_DIR="$(pwd)/template"
        mkdir -p "$TEMPLATE_DIR"

        echo "Generating build_info.txt..."
        {
            echo "device=$DEVICE_CODENAME"
            echo "version=$LUMIROM_VERSION-$BUILD_DATE"
            echo "timestamp=$TIMESTAMP"
            echo "status=$BUILD_STATUS"
        } > "$TEMPLATE_DIR/build_info.txt"

        SPECIFIC_BOOT="$(pwd)/LumiROM/Devices/$DEVICE/boot.img"

        if [ -f "$SPECIFIC_BOOT" ]; then
            echo -e "${GREEN}-> Copying boot.img from${RESET} $DEVICE..."
            cp "$SPECIFIC_BOOT" "$TEMPLATE_DIR/boot.img"
        else
            echo -e "${RED}There is no boot.img for${RESET} $DEVICE"
        fi

        echo -e "${GREEN}Moving compressed DAT files to template...${RESET}"
        mv TMP/*.new.dat.br "$TEMPLATE_DIR"/
        mv TMP/*.patch.dat "$TEMPLATE_DIR"/
        mv TMP/*.transfer.list "$TEMPLATE_DIR"/ 2>/dev/null || true

        echo -e "${GREEN}Creating ZIP package...${RESET}"
        ZIP_FILE="LumiROM_${LUMIROM_VERSION}-${BUILD_DATE}_${DEVICE_CODENAME}.zip"
        [ -f "$ZIP_FILE" ] && rm "$ZIP_FILE"

        cd "$TEMPLATE_DIR"

        # ZIP the rom with mixed compression levels (Multithreaded 7z)
        echo -e "${YELLOW}Adding large/compressed files (Store)...${RESET}"
        7z a -mx=0 -mmt=4 "$ZIP_FILE" ./*.new.dat.br ./*.patch.dat 2>/dev/null || true
        
        echo -e "${YELLOW}Adding scripts and compressible data (Compress)...${RESET}"
        7z a -mx=6 -mmt=4 "$ZIP_FILE" ./boot.img ./META-INF ./build_info.txt ./dynamic_partitions_op_list ./*.transfer.list 2>/dev/null || true

        mkdir -p "../ROM/${BUILD_DATE}-${TIMESTAMP}/"
        mv "$ZIP_FILE" "../ROM/${BUILD_DATE}-${TIMESTAMP}/"

        echo -e "${GREEN}ZIP package created: $ZIP_FILE${RESET}"

        cd ..
}