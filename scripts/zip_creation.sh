#!/bin/bash

UPDATE_ZIP_SCRIPT() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <ZIP_WORK_DIR>"
        return 1
    fi
    
    local EXTRACTED_FIRM_DIR="$1"
    local ZIP_WORK_DIR="$2"
    BUILD_PROP_PATH="$EXTRACTED_FIRM_DIR/system/system/build.prop"
    FINGERPRINT=$(grep -m 1 "ro.system.build.fingerprint=" "$BUILD_PROP_PATH" | cut -d'=' -f2)
    BUILD_DATE=$(date +'%d%m%Y')
    DEVICE="$STOCK_DEVICE"
    UPDATER_PATH="$ZIP_WORK_DIR/META-INF/com/google/android/updater-script"

        if [[ "$DEVICE" == "SM-A325F" || "$DEVICE" == "SM-A325M" ]]; then
            DEVICE_CODENAME="a32"
            DISPLAY_NAME="Galaxy A32 4G"
        elif [[ "$DEVICE" == "SM-A225F" ]]; then
            DEVICE_CODENAME="a22"
            DISPLAY_NAME="Galaxy A22 4G"
        elif [[ "$DEVICE" == "SM-A225M" ]]; then
            DEVICE_CODENAME="a22ub"
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
        elif [[ "$DEVICE" == "SM-M225F" ]]; then
            DEVICE_CODENAME="m22"
            DISPLAY_NAME="Galaxy M22 4G"
        else
            DEVICE_CODENAME="unknown"
            DISPLAY_NAME="Unknown Device"
        fi

        if [ -z "$FINGERPRINT" ]; then
            echo "Warning: Fingerprint not found, using generic value."
            FINGERPRINT="Unknown/Release-Keys"
        fi

        echo "Detected Fingerprint: $FINGERPRINT"
        sed -i "s!ui_print(\"Source: .*\");!ui_print(\"Source: $FINGERPRINT\");!" "$UPDATER_PATH"
        
        NEW_CHECK="getprop(\"ro.boot.em.model\") == \"$DEVICE\" || abort(\"E3004: This package is for $DEVICE_CODENAME\");"

        echo "Updating device on updater-script for $DISPLAY_NAME..."
      
        sed -i "s!^getprop(\"ro.boot.em.model\").*!$NEW_CHECK!" "$UPDATER_PATH"

        sed -i "s!ui_print(\".*for .*\");!ui_print(\"   $LUMIROM_VERSION-$BUILD_DATE $BUILD_STATUS for $DISPLAY_NAME\");!" "$UPDATER_PATH"

}

FLASHABLE_ZIP_CREATION() {
    local EXTRACTED_FIRM_DIR="$1"
    local BUILD_DATE=$(date +'%d%m%Y')
    local TIMESTAMP=$(date +'%s')
    local DEVICE="$STOCK_DEVICE"
    local WS_ROOT="$(pwd)"
    local TEMPLATE_DIR="$WS_ROOT/template"
    local TMP_DIR="$WS_ROOT/TMP"

    # 1. Gather Metadata and Boot
    if [[ "$DEVICE" == "SM-A325F" || "$DEVICE" == "SM-A325M" ]]; then DEVICE_CODENAME="a32"
    elif [[ "$DEVICE" == "SM-A225F" ]]; then DEVICE_CODENAME="a22"
    elif [[ "$DEVICE" == "SM-A225M" ]]; then DEVICE_CODENAME="a22ub"
    elif [[ "$DEVICE" == "SM-A226B" ]]; then DEVICE_CODENAME="a22x"
    elif [[ "$DEVICE" == "SM-M325F" ]]; then DEVICE_CODENAME="m32"
    elif [[ "$DEVICE" == "SM-M325F" ]]; then DEVICE_CODENAME="m32"
    elif [[ "$DEVICE" == "SM-E225F" ]]; then DEVICE_CODENAME="f22"
    elif [[ "$DEVICE" == "SM-M225F" ]]; then DEVICE_CODENAME="m22"
    else DEVICE_CODENAME="unknown"; fi

    echo "--- Preparing Flashable ZIP ($DEVICE_CODENAME) ---"
    
    local ZIP_WORK_DIR="$OUT_DIR/ZIP_PACKAGE"
    # Ensure fresh workspace based on static template
    rm -rf "$ZIP_WORK_DIR" && mkdir -p "$ZIP_WORK_DIR"
    cp -rp "$TEMPLATE_DIR/"* "$ZIP_WORK_DIR/"

    # Generate build info
    {
        echo "device=$DEVICE_CODENAME"
        echo "version=$LUMIROM_VERSION-$BUILD_DATE"
        echo "timestamp=$TIMESTAMP"
        echo "status=$BUILD_STATUS"
    } > "$ZIP_WORK_DIR/build_info.txt"

    # Copy boot.img if specific one exists
    local SPECIFIC_BOOT="$WS_ROOT/LumiROM/Devices/$DEVICE/boot.img"
    if [ -f "$SPECIFIC_BOOT" ]; then
        cp "$SPECIFIC_BOOT" "$ZIP_WORK_DIR/boot.img"
    fi

    # 2. ZIP Creation (Multi-stage Zero Copy)
    local ZIP_FILE="LumiROM_${LUMIROM_VERSION}-${BUILD_DATE}_${DEVICE_CODENAME}.zip"
    [ -f "$OUT_DIR/$ZIP_FILE" ] && rm "$OUT_DIR/$ZIP_FILE"

    # First add base template files (compressible)
    echo "  Adding scripts and metadata (Compress)..."
    (
        cd "$ZIP_WORK_DIR"
        RUN_SILENT 7z a -mx=6 -mmt=4 "$OUT_DIR/$ZIP_FILE" \
            ./boot.img ./META-INF ./build_info.txt ./dynamic_partitions_op_list ./*.transfer.list
    ) 2>/dev/null || true

    # Then append large binary assets (store level)
    if [ -d "$TMP_DIR" ]; then
        echo "  Appending large ROM assets (Store)..."
        (
            cd "$TMP_DIR"
            RUN_SILENT 7z a -mx=0 -mmt=4 "$OUT_DIR/$ZIP_FILE" \
                ./*.new.dat.br ./*.patch.dat
        ) 2>/dev/null || true
    fi

    echo "ZIP package created: $OUT_DIR/$ZIP_FILE"
    [ -n "$GITHUB_ENV" ] && echo "ZIP_NAME=$ZIP_FILE" >> "$GITHUB_ENV" || true
}