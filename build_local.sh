#!/bin/bash

START_TIME=$(date +%s)

# Variables that need an input from the user
STOCK_DEVICE="$1"
TARGET_DEVICE="$2"
TARGET_CSC="$3"
TARGET_IMEI="$4"
USE_MODS="$5"
USE_GALAXY_AI="$6"
USE_UI_8_TETHERING_APEX="$7"
LUMIROM_MAINTAINER="$8"

source scripts/validation.sh
VALIDATION

# A346B imei = 352990180814770
# A245F imei = 358212589089183

# --- System Environment Variables ---
export OUTPUT_FILESYSTEM="erofs"
export LUMIROM_VERSION="8.6.3"
export LUMIROM_CODE="${LUMIROM_VERSION//./0}"
export OUT_DIR="$PWD/OUT"
export WORK_DIR="$PWD/TMP/LumiWORK"
export FIRM_DIR="$PWD/FIRMWARE"
export IMGS_DIR="$PWD/IMGs"
export DEVICES_DIR="$PWD/LumiROM/Devices"
export APKTOOL="$PWD/bin/apktool/apktool.jar"
export VNDKS_COLLECTION="$PWD/LumiROM/vndks"
export BUILD_PARTITIONS="product,vendor,odm,system_ext,system"

# --- Load Logging System ---
source scripts/logging.sh
initialize_logs "$STOCK_DEVICE" "$TARGET_DEVICE" "$TARGET_CSC" "$TARGET_IMEI" "$LUMIROM_VERSION" "$USE_MODS" "$USE_GALAXY_AI" "$USE_UI_8_TETHERING_APEX" "$OUTPUT_FILESYSTEM" "$LUMIROM_MAINTAINER"

# --- Start of Process ---

# Give execution permissions
log_section "Setting up permissions"
chmod +x scripts/*.sh
chmod +x bin/MergeOTA/MergeAll.sh
chmod +x bin/erofs-utils/extract.erofs
chmod +x bin/erofs-utils/mkfs.erofs
chmod +x bin/lp/*
log_message "Permissions set successfully"

log_section "Installing required packages"
bash scripts/install_packages.sh 2>&1 | tee -a "$LOG_FILE"
clear

log_section "Setting up directories"
mkdir -p "$WORK_DIR"
bash scripts/setup_directories.sh FIRMWARE WORK OUT ROM TMP IMGs LOGS 2>&1 | tee -a "$LOG_FILE"

log_section "Checking the environment"
source scripts/local_official.sh 
IS_LOCAL_OFFICIAL >> "$LOG_FILE" 2>&1

log_section "Downloading Firmware"
source scripts/FW.sh
source "$DEVICES_DIR/$STOCK_DEVICE/config"

# Check if firmware images are already cached
log_message "Checking firmware cache..."
if CHECK_FIRMWARE_IMAGES "$IMGS_DIR" "$BUILD_PARTITIONS"; then
    log_message "✓ Firmware cache found. Skipping download..."
else
    log_message "✗ No firmware cache found. Proceeding with download..."
    DOWNLOAD_FIRMWARE "$TARGET_DEVICE" "$TARGET_CSC" "$TARGET_IMEI" "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
fi

if [[ -f "IMGs/${TARGET_DEVICE}.zip" ]]; then
    log_section "Extracting $TARGET_DEVICE images"
    EXTRACT_FIRMWARE "$IMGS_DIR" 2>&1 | tee -a "$LOG_FILE"
    EXTRACT_SUPER_IMG "$IMGS_DIR" 2>&1 | tee -a "$LOG_FILE"
fi

# Check if vendor image is already cached
log_message "Checking vendor cache..."
if CHECK_VENDOR_IMAGE "$IMGS_DIR"; then
    log_message "✓ Vendor cache found. Skipping download..."
    sleep 1
else
    log_message "✗ No vendor cache found. Proceeding with download..."
    DOWNLOAD_VENDOR "$IMGS_DIR" 2>&1 | tee -a "$LOG_FILE"
fi
log_section "Preparing partitions"
PREPARE_PARTITIONS "$IMGS_DIR" 2>&1 | tee -a "$LOG_FILE"
EXTRACT_FIRMWARE_IMG "$IMGS_DIR" "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"

source scripts/LumiROM.sh
log_message "Loading LumiROM functions..."
DISABLE_FBE "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
DISABLE_FDE "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
DELETE_ICCC "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
DEBLOAT_VENDOR "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
PATCH_FSTAB_EROFS "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
APPLY_STOCK_CONFIG "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
DEBLOAT "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
APPLY_PROP_FEATURES "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"

if [ "$USE_MODS" = "true" ]; then
    log_section "Adding Mods"
    source scripts/Mods.sh
    ADD_MODS "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
fi

if [ "$USE_GALAXY_AI" = "true" ]; then
    log_section "Adding Galaxy AI"
    source scripts/Galaxy_AI.sh
    GALAXY_AI "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
fi

log_section "Appending Display ID"
APPENDING_DISPLAY_ID "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
INSTALL_FRAMEWORK "FIRMWARE/system/system/framework/framework-res.apk" 2>&1 | tee -a "$LOG_FILE"

log_section "Patching Knox and Framework"
DECOMPILE "$APKTOOL" "FIRMWARE/system/system/framework/ssrm.jar" "$WORK_DIR" 2>&1 | tee -a "$LOG_FILE" &
DECOMPILE "$APKTOOL" "FIRMWARE/system/system/framework/services.jar" "$WORK_DIR" 2>&1 | tee -a "$LOG_FILE" &
wait

log_section "Applying Knox and Framework patches"
source scripts/Knox_script.sh
PATCH_SSRM "$WORK_DIR/ssrm" 2>&1 | tee -a "$LOG_FILE"
PATCH_KNOX_GUARD "$WORK_DIR/services" 2>&1 | tee -a "$LOG_FILE"
PATCH_FLAG_SECURE "$WORK_DIR/services" 2>&1 | tee -a "$LOG_FILE"
PATCH_SECURE_FOLDER "$WORK_DIR/services" 2>&1 | tee -a "$LOG_FILE"
PATCH_PRIVATE_SHARE "$WORK_DIR/services" 2>&1 | tee -a "$LOG_FILE"
DISABLE_SIGNATURE_VERIFICATION "$WORK_DIR/services" 2>&1 | tee -a "$LOG_FILE"

log_section "Recompiling Knox and Framework"
RECOMPILE "$APKTOOL" "$WORK_DIR/ssrm" "FIRMWARE/system/system/framework" "$WORK_DIR" 2>&1 | tee -a "$LOG_FILE" &
RECOMPILE "$APKTOOL" "$WORK_DIR/services" "FIRMWARE/system/system/framework" "$WORK_DIR" 2>&1 | tee -a "$LOG_FILE" &
wait
cp -fv "$WORK_DIR"/*.jar "FIRMWARE/system/system/framework/" 2>&1 | tee -a "$LOG_FILE"

log_section "Building ROM"
source scripts/LumiROM.sh 2>&1 | tee -a "$LOG_FILE"
BUILD_IMG "$FIRM_DIR" "$OUTPUT_FILESYSTEM" "$OUT_DIR" 2>&1 | tee -a "$LOG_FILE"
IMG_TO_BROTLI "$OUT_DIR" "TMP" 2>&1 | tee -a "$LOG_FILE"

log_section "Creating flashable ZIP"
source scripts/zip_creation.sh
UPDATE_ZIP_SCRIPT "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
FLASHABLE_ZIP_CREATION 2>&1 | tee -a "$LOG_FILE"

log_message "Cleaning up temporary directories..."
rm -rf ./OUT/ ./TMP/ ./WORK/ ./FIRMWARE/ 2>&1 | tee -a "$LOG_FILE"

log_message "✓ LumiROM $LUMIROM_VERSION for $STOCK_DEVICE is ready!"
log_message "✓ You can find it in the ROM folder"

# Generate build summary and finalize logs
finalize_logs "$START_TIME"
