#!/bin/bash

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


if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <STOCK_DEVICE> <USE_UI_8_TETHERING_APEX> <OUTPUT_FILESYSTEM>"
    exit 1
fi

# Device info
export STOCK_DEVICE="$1"
export USE_UI_8_TETHERING_APEX="$2"
export OUTPUT_FILESYSTEM="$3"

# Directories
export OUT_DIR="$(pwd)/OUT"
export WORK_DIR="$(pwd)/WORK"
export FIRM_DIR="$(pwd)/FIRMWARE"
export DEVICES_DIR="$(pwd)/LumiROM/Devices"
export APKTOOL="$(pwd)/bin/apktool/apktool.jar"
export VNDKS_COLLECTION="$(pwd)/LumiROM/vndks"

export BUILD_PARTITIONS="product,vendor,odm,system_ext,system"

# Source
source "$(pwd)/scripts/LumiROM.sh"
source "$DEVICES_DIR/$STOCK_DEVICE/config"

DOWNLOAD_FIRMWARE "$TARGET_DEVICE" "$FIRM_DIR"

EXTRACT_FIRMWARE "$FIRM_DIR/$TARGET_DEVICE"
PREPARE_PARTITIONS "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE"

APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"

DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"
APPLY_FEATURES "$FIRM_DIR/$TARGET_DEVICE"

INSTALL_FRAMEWORK "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"

DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/ssrm.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/services.jar" "$WORK_DIR"

PATCH_SSRM "$WORK_DIR/ssrm"
PATCH_KNOX_GUARD "$WORK_DIR/services"
PATCH_FLAG_SECURE "$WORK_DIR/services"
PATCH_SECURE_FOLDER "$WORK_DIR/services"

RECOMPILE "$APKTOOL" "$WORK_DIR/ssrm" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$WORK_DIR/services" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR"
cp -fv "$WORK_DIR"/*.jar "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/"

BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
