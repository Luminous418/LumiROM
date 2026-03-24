#!/bin/bash

# This script does exactly the same as OneUi8-5.yml
# but does all in local so no need to use GitHub


set -Eeuo pipefail

trap '{
    EXIT_CODE=$?
    LINE_NO=${BASH_LINENO[0]}
    CMD=${BASH_COMMAND}

    echo ""
    echo "❌ Build failed!"
    echo "➡️ Line     : $LINE_NO"
    echo "➡️ Command  : $CMD"
    echo "➡️ Exit code: $EXIT_CODE"
    echo ""

    exit $EXIT_CODE
}' ERR


if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <STOCK_DEVICE> <USE_UI_8_TETHERING_APEX>"
    exit 1
fi

# Device info
export STOCK_DEVICE="$1"
export USE_UI_8_TETHERING_APEX="$2"

        if [[ "$STOCK_DEVICE" == "SM-A325F" || "$STOCK_DEVICE" == "SM-A325M" || "$STOCK_DEVICE" == "SM-M325F" || "$STOCK_DEVICE" == "SM-A226B" ]]; then
            export TARGET_DEVICE="SM-A346B"
        elif [[ "$STOCK_DEVICE" == "SM-A225F" || "$STOCK_DEVICE" == "SM-A225M" || "$STOCK_DEVICE" == "SM-E225F" || "$STOCK_DEVICE" == "SM-M225F" ]]; then
            export TARGET_DEVICE="SM-A155F"
        else
            $STOCK_DEVICE="unknown"
        fi

export OUTPUT_FILESYSTEM="erofs"
export LUMIROM_VERSION=8.6.0

# Directories
export OUT_DIR="$(pwd)/OUT"
export WORK_DIR="$(pwd)/WORK"
export FIRM_DIR="$(pwd)/FIRMWARE"
export DEVICES_DIR="$(pwd)/LumiROM/Devices"
export APKTOOL="$(pwd)/bin/apktool/apktool.jar"
export VNDKS_COLLECTION="$(pwd)/LumiROM/vndks"

# Partitions to build
export BUILD_PARTITIONS="product,vendor,odm,system_ext,system"

# Source
source "$(pwd)/scripts/LumiROM.sh"
source "$DEVICES_DIR/$STOCK_DEVICE/config"

# Download firmware
DOWNLOAD_FIRMWARE "$TARGET_DEVICE" "$FIRM_DIR"

# Extract firmware
EXTRACT_FIRMWARE "$FIRM_DIR/$TARGET_DEVICE"
PREPARE_PARTITIONS "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE"

# Apply vendor patches
DISABLE_FBE "$FIRM_DIR/$TARGET_DEVICE"
DISABLE_FDE "$FIRM_DIR/$TARGET_DEVICE"
DELETE_ICCC "$FIRM_DIR/$TARGET_DEVICE"
PATCH_FSTAB_EROFS "$FIRM_DIR/$TARGET_DEVICE"

# Apply stock config
APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"

# Debloat ROM
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"

# Apply features
APPLY_FEATURES "$FIRM_DIR/$TARGET_DEVICE"

# Update Build ID
APPENDING_DISPLAY_ID "$FIRM_DIR/$TARGET_DEVICE"

# Install stock framework-res
INSTALL_FRAMEWORK "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"

# Decompile framework jars
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/ssrm.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/services.jar" "$WORK_DIR"

# Patch framework
PATCH_SSRM "$WORK_DIR/ssrm"
PATCH_KNOX_GUARD "$WORK_DIR/services"
PATCH_FLAG_SECURE "$WORK_DIR/services"
PATCH_SECURE_FOLDER "$WORK_DIR/services"

# Recompile framework
RECOMPILE "$APKTOOL" "$WORK_DIR/ssrm" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$WORK_DIR/services" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR"
cp -fv "$WORK_DIR"/*.jar "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/"

# Build ROM
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
IMG_TO_BROTLI "$OUT_DIR" "TMP"


source "$(pwd)/scripts/zip_creation.sh"

# Update updater-script
UPDATE_ZIP_SCRIPT "$FIRM_DIR/$TARGET_DEVICE"

# Prepare flashable zip
FLASHABLE_ZIP_CREATION
