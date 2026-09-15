#!/bin/bash

source scripts/utils/bash_colors.sh

UPDATE_ZIP_SCRIPT() {
    
        local EXTRACTED_FIRM_DIR="$1"
        BUILD_PROP_PATH="$EXTRACTED_FIRM_DIR/system/system/build.prop"
        FINGERPRINT=$(grep -m 1 "ro.system.build.fingerprint=" "$BUILD_PROP_PATH" | cut -d'=' -f2)
        BUILD_DATE=$(date +'%d%m%Y')
        DEVICE="$STOCK_DEVICE"
        UPDATER_PATH="$(pwd)/makerom/META-INF/com/google/android/updater-script"
        local oneui_prop_ver=$(grep -m 1 "ro.build.version.oneui=" "$BUILD_PROP_PATH" | cut -d'=' -f2)
        local cut_version="${oneui_prop_ver:0:3}"
        ONEUI_VERSION="${cut_version/0/.}"

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
            echo "${YELLOW}Warning: Fingerprint not found, using generic value.${RESET}"
            FINGERPRINT="Unknown/Release-Keys"
        fi

        echo "${GREEN}Detected Fingerprint:${RESET} $FINGERPRINT"
        sed -i "s!ui_print(\"Source: .*\");!ui_print(\"Source: $FINGERPRINT\");!" "$UPDATER_PATH"
        
        NEW_CHECK="getprop(\"ro.boot.em.model\") == \"$DEVICE\" || abort(\"E3004: This package is for $DEVICE_CODENAME\");"

        echo "${GREEN}Updating device on updater-script for${RESET} $DISPLAY_NAME..."
      
        sed -i "s!^getprop(\"ro.boot.em.model\").*!$NEW_CHECK!" "$UPDATER_PATH"

        sed -i "s!ui_print(\".*for .*\");!ui_print(\"   $LUMIROM_VERSION-$BUILD_DATE $BUILD_STATUS for $DISPLAY_NAME\");!" "$UPDATER_PATH"

        echo "${GREEN}Updating One UI version to${RESET} $ONEUI_VERSION ${GREEN}on updater-script...${RESET}"

        sed -i "s!ui_print(\"One UI version: .*\");!ui_print(\"One UI version: $ONEUI_VERSION\");!" "$UPDATER_PATH"

}

FLASHABLE_ZIP_CREATION() {
    
        BUILD_DATE=$(date +'%d%m%Y')
        TIMESTAMP=$(date +'%s')
        DEVICE="$STOCK_DEVICE"
        local cut_version_stock="${STOCK_DEVICE:3:3}"
        local cut_version_target="${TARGET_DEVICE:3:3}"
        FOLDER_NAME="${BUILD_DATE}-${TIMESTAMP}-${cut_version_stock}_to_${cut_version_target}/"
        MAKEROM_DIR="$(pwd)/makerom"
        export FOLDER_NAME

        if [ -n "$GITHUB_ENV" ]; then
            echo "FOLDER_NAME=$FOLDER_NAME" >> "$GITHUB_ENV"
        fi

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

        echo "Generating build_info.txt..."
        if [ -n "$GITHUB_ENV" ]; then
            echo "DEVICE_CODENAME=$DEVICE_CODENAME" >> "$GITHUB_ENV"
        fi

        source "$DEVICES_DIR/$STOCK_DEVICE/config" 2>/dev/null || true

        BUILD_PROP="$FIRM_DIR/system/system/build.prop"
        if [ -z "$FINGERPRINT" ]; then
            FINGERPRINT="$(grep "^ro.system.build.fingerprint=" "$BUILD_PROP" | cut -d "=" -f 2)"
        fi
        if [ -z "$ONEUI_VERSION" ]; then
            ONEUI_VERSION="$(grep "^ro.build.version.oneui=" "$BUILD_PROP" | cut -d "=" -f 2)"
            ONEUI_VERSION="${ONEUI_VERSION:0:3}"
            ONEUI_VERSION="${ONEUI_VERSION/0/.}"
        fi
        ANDROID_VERSION="$(grep "^ro.build.version.release=" "$BUILD_PROP" | cut -d "=" -f 2)"
        SECURITY_PATCH="$(grep "^ro.build.version.security_patch=" "$BUILD_PROP" | cut -d "=" -f 2)"

        {
            echo "device=$DEVICE_CODENAME"
            echo "device_model=$STOCK_DEVICE"
            echo "version=$LUMIROM_VERSION-$BUILD_DATE"
            echo "version_code=$LUMIROM_CODE"
            echo "build_date=$(date +%F)"
            echo "android_version=$ANDROID_VERSION"
            echo "oneui_version=$ONEUI_VERSION"
            echo "security_patch=$SECURITY_PATCH"
            echo "build_fingerprint=$FINGERPRINT"
            echo "kernel_version=$KERNEL_VERSION"
            echo "partition_layout=a-only"
            echo "timestamp=$TIMESTAMP"
            echo "status=$BUILD_STATUS"
        } > "$MAKEROM_DIR/build_info.txt"

        cp "$MAKEROM_DIR/build_info.txt" "$OUT_DIR/build_info.txt" 2>/dev/null || true

        SPECIFIC_BOOT="$(pwd)/LumiROM/Devices/$DEVICE/boot.img"

        if [ -f "$SPECIFIC_BOOT" ]; then
            echo "${GREEN}-> Copying boot.img from${RESET} $DEVICE..."
            cp "$SPECIFIC_BOOT" "$MAKEROM_DIR/boot.img"
        else
            echo "${RED}There is no boot.img for${RESET} $DEVICE"
        fi

        echo "${GREEN}Moving compressed DAT files to ROM Folder...${RESET}"
        mv TMP/*.new.dat.br "$MAKEROM_DIR"/
        mv TMP/*.patch.dat "$MAKEROM_DIR"/
        mv TMP/*.transfer.list "$MAKEROM_DIR"/ 2>/dev/null || true

        echo "${GREEN}Creating ZIP package...${RESET}"
        ZIP_FILE="LumiROM_${LUMIROM_VERSION}-${BUILD_DATE}_${BUILD_STATUS}_${DEVICE_CODENAME}.zip"
        [ -f "$ZIP_FILE" ] && rm "$ZIP_FILE"

        cd "$MAKEROM_DIR"

        # ZIP the rom with mixed compression levels (Multithreaded 7z)
        echo "${YELLOW}Adding large/compressed files (Store)...${RESET}"
        7z a -mx=0 -mmt=4 "$ZIP_FILE" ./*.new.dat.br ./*.patch.dat 2>/dev/null || true
        
        echo "${YELLOW}Adding scripts and compressible data (Compress)...${RESET}"
        7z a -mx=6 -mmt=4 "$ZIP_FILE" ./boot.img ./META-INF ./build_info.txt ./dynamic_partitions_op_list ./*.transfer.list 2>/dev/null || true
        

        mkdir -p "../ROM/${FOLDER_NAME}"
        mv "$ZIP_FILE" "../ROM/${FOLDER_NAME}"

        echo "${GREEN}ZIP package created: $ZIP_FILE${RESET}"

        cd ..
        rm -rf "$MAKEROM_DIR"
}

ZIP_IMG() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <IMG_DIR> <OUT_ZIP>"
        return 1
    fi

    local IMG_DIR="$1"
    local OUT_ZIP="$2"

    echo "${BLUE}=== Creating ZIP from IMG files ===${RESET}"

    if ! ls "$IMG_DIR"/*.img >/dev/null 2>&1; then
        echo "${RED}Error: No .img files found in $IMG_DIR${RESET}"
        return 1
    fi

    mkdir -p "$(dirname "$OUT_ZIP")"

    if zip -0 -j "$OUT_ZIP" "$IMG_DIR"/*.img; then
        echo "${GREEN}ZIP created successfully: $OUT_ZIP${RESET}"
    else
        echo "${RED}Error: Failed to create ZIP file${RESET}"
        return 1
    fi
}

IMG_ZIP_CREATION() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <OUT_DIR>"
        return 1
    fi

    local OUT_DIR="$1"

    BUILD_DATE=$(date +'%d%m%Y')
    TIMESTAMP=$(date +'%s')
    DEVICE="$STOCK_DEVICE"
    local cut_version_stock="${STOCK_DEVICE:3:3}"
    local cut_version_target="${TARGET_DEVICE:3:3}"
    FOLDER_NAME="${BUILD_DATE}-${TIMESTAMP}-${cut_version_stock}_to_${cut_version_target}/"
    export FOLDER_NAME

    if [ -n "$GITHUB_ENV" ]; then
        echo "FOLDER_NAME=$FOLDER_NAME" >> "$GITHUB_ENV"
    fi

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

    local ZIP_FILE="LumiROM_${LUMIROM_VERSION}-${BUILD_DATE}_${BUILD_STATUS}_${DEVICE_CODENAME}_IMG.zip"

    ZIP_IMG "$OUT_DIR" "$(pwd)/ROM/${FOLDER_NAME}${ZIP_FILE}"
}
CREATE_TARGET_FILES() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <OUTPUT_ZIP>"
        return 1
    fi

    local OUTPUT_ZIP="$1"

    if ! ls "$OUT_DIR"/*.img >/dev/null 2>&1; then
        echo "${RED}Error: No .img files found in $OUT_DIR${RESET}"
        return 1
    fi

    if [ ! -f "$OUT_DIR/build_info.txt" ]; then
        echo "${RED}Error: build_info.txt not found in $OUT_DIR${RESET}"
        return 1
    fi

    local WORK_DIR_TF
    mkdir -p "$(pwd)/TMP"
    WORK_DIR_TF="$(mktemp -d -p "$(pwd)/TMP")"

    cp "$OUT_DIR"/*.img "$WORK_DIR_TF"/
    cp "$OUT_DIR"/*.map "$WORK_DIR_TF"/ 2>/dev/null || true
    cp "$OUT_DIR/build_info.txt" "$WORK_DIR_TF"/

    local SPECIFIC_BOOT="$(pwd)/LumiROM/Devices/$STOCK_DEVICE/boot.img"
    [ -f "$SPECIFIC_BOOT" ] && cp "$SPECIFIC_BOOT" "$WORK_DIR_TF"/

    mkdir -p "$(dirname "$OUTPUT_ZIP")"
    rm -f "$OUTPUT_ZIP"
    (cd "$WORK_DIR_TF" && zip -q -r "$OUTPUT_ZIP" .)
    rm -rf "$WORK_DIR_TF"

    echo "${GREEN}Target files created: $OUTPUT_ZIP${RESET}"
}
