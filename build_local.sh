#!/bin/bash

# --- Variable Configuration ---
# Edit these values according to what you need for your build
STOCK_DEVICE="SM-A325F"
USE_MODS="Yes"
USE_GALAXY_AI="Yes"
USE_UI_8_TETHERING_APEX="False"
TARGET_DEVICE="SM-A346B"
TARGET_DEVICE_CSC="EUX"
TARGET_DEVICE_IMEI="351648442869815"
TARGET_FW_VERSION="A346BXXSFEZC7/A346BOXMFEZC7/A346BXXSFEZC7/A346BXXSFEZC7"

# Secrets
LUMIROM_BUILD=""
OFFICIAL_HASH=""

# --- System Environment Variables ---
export OUTPUT_FILESYSTEM="erofs"
export LUMIROM_VERSION="8.6.2"
export OUT_DIR="$PWD/OUT"
export WORK_DIR="/tmp/LumiWORK"
export FIRM_DIR="$PWD/FIRMWARE"
export DEVICES_DIR="$PWD/LumiROM/Devices"
export APKTOOL="$PWD/bin/apktool/apktool.jar"
export VNDKS_COLLECTION="$PWD/LumiROM/vndks"
export BUILD_PARTITIONS="product,vendor,odm,system_ext,system"

# --- Start of Process ---

# Give execution permissions
chmod +x scripts/*.sh
chmod +x bin/erofs-utils/extract.erofs
chmod +x bin/erofs-utils/mkfs.erofs
chmod +x bin/MergeOTA/MergeAll.sh

echo "--- Installing required packages ---"
bash scripts/install_packages.sh

echo "--- Setting up directories ---"
mkdir -p "$WORK_DIR"
bash scripts/setup_directories.sh FIRMWARE WORK OUT OTA ROM

echo "--- Verifying enviroment ---"
source scripts/LumiROM.sh
export LUMIROM_BUILD OFFICIAL_HASH
IS_OFFICIAL

echo "--- Downloading Firmware and OTA ---"
source scripts/FW.sh
source "$DEVICES_DIR/$STOCK_DEVICE/config"

# Check if firmware images are already cached
if CHECK_FIRMWARE_IMAGES "$FIRM_DIR" "$BUILD_PARTITIONS"; then
    echo -e "${GREEN}Firmware cache found. Skipping download...${RESET}"
else
    echo -e "${YELLOW}No firmware cache found. Proceeding with download...${RESET}"
    DOWNLOAD_FIRMWARE_LUMI "FIRMWARE"
    DOWNLOAD_OTA "OTA"
    MERGE_OTA "FIRMWARE" "OTA"
fi

# Check if vendor image is already cached
if CHECK_VENDOR_IMAGE "$FIRM_DIR"; then
    echo -e "${GREEN}Vendor cache found. Skipping download...${RESET}"
else
    echo -e "${YELLOW}No vendor cache found. Proceeding with download...${RESET}"
    DOWNLOAD_VENDOR "FIRMWARE"
fi

echo "--- Extracting and patching ---"
PREPARE_PARTITIONS "FIRMWARE"
EXTRACT_FIRMWARE_IMG "FIRMWARE"

source scripts/LumiROM.sh
DISABLE_FBE "FIRMWARE"
DISABLE_FDE "FIRMWARE"
DELETE_ICCC "FIRMWARE"
DEBLOAT_VENDOR "FIRMWARE"
PATCH_FSTAB_EROFS "FIRMWARE"
APPLY_STOCK_CONFIG "FIRMWARE"
DEBLOAT "FIRMWARE"
APPLY_FEATURES "FIRMWARE"

if [ "$USE_MODS" = "Yes" ]; then
    echo "--- Adding Mods ---"
    source scripts/Mods.sh
    ADD_MODS "FIRMWARE"
fi

if [ "$USE_GALAXY_AI" = "Yes" ]; then
    echo "--- Adding Galaxy AI ---"
    source scripts/Galaxy_AI.sh
    GALAXY_AI "FIRMWARE"
fi

echo "--- Appending Display ID ---"
APPENDING_DISPLAY_ID "FIRMWARE"
INSTALL_FRAMEWORK "FIRMWARE/system/system/framework/framework-res.apk"

echo "--- Patching Knox and Framework ---"
DECOMPILE "$APKTOOL" "FIRMWARE/system/system/framework/ssrm.jar" "$WORK_DIR" &
DECOMPILE "$APKTOOL" "FIRMWARE/system/system/framework/services.jar" "$WORK_DIR" &
wait

echo "--- Applying Knox and Framework patches ---"
source scripts/Knox_script.sh
PATCH_SSRM "$WORK_DIR/ssrm"
PATCH_KNOX_GUARD "$WORK_DIR/services"
PATCH_FLAG_SECURE "$WORK_DIR/services"
PATCH_SECURE_FOLDER "$WORK_DIR/services"
PATCH_PRIVATE_SHARE "$WORK_DIR/services"
DISABLE_SIGNATURE_VERIFICATION "$WORK_DIR/services"

echo "--- Recompiling Knox and Framework ---"
RECOMPILE "$APKTOOL" "$WORK_DIR/ssrm" "FIRMWARE/system/system/framework" "$WORK_DIR" &
RECOMPILE "$APKTOOL" "$WORK_DIR/services" "FIRMWARE/system/system/framework" "$WORK_DIR" &
wait
cp -fv "$WORK_DIR"/*.jar "FIRMWARE/system/system/framework/"

echo "--- Building ROM ---"
source scripts/LumiROM.sh
BUILD_IMG "FIRMWARE" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
IMG_TO_BROTLI "$OUT_DIR" "TMP"

echo "--- Creating flashable ZIP ---"
source scripts/zip_creation.sh
UPDATE_ZIP_SCRIPT "FIRMWARE"
FLASHABLE_ZIP_CREATION

echo "LumiROM $LUMIROM_VERSION for $STOCK_DEVICE is ready, you can find it on ROM folder"

echo "--- Process finished ---"