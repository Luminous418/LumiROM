#!/bin/bash

START_TIME=$(date +%s)

# Defaults
USE_MODS="true"
USE_GALAXY_AI="true"
USE_UI_8_TETHERING_APEX="false"
ZIP_IMG="false"
INCREMENTAL_FROM=""
LUMIROM_MAINTAINER="$(git config user.name 2>/dev/null)"

usage() {
    echo "LumiROM local builder"
    echo ""
    echo "Usage: bash build_local.sh -s <STOCK_DEVICE> -c <CSC> -i <IMEI> [options]"
    echo ""
    echo "Required:"
    echo "  -s, --stock <SM-XXXXX>     Your phone model (must be supported)"
    echo "  -c, --csc <XXX>            Region code of the base firmware (3 letters)"
    echo "  -i, --imei <15 digits>     Valid IMEI of the base device"
    echo ""
    echo "Optional:"
    echo "  -t, --target <SM-XXXXX>    Base device to port from (auto-derived from stock if omitted)"
    echo "  -m, --maintainer <name>    Maintainer name (default: git config user.name)"
    echo "      --no-mods              Exclude mods (Cloudy app, Vulkan fix, VoLTE fix, tweaks, wallpapers)"
    echo "      --no-ai                Exclude Galaxy AI features"
    echo "      --bpf-legacy           Enable if your kernel BPF version is lower than 5.10"
    echo "      --img-zip              Deliver the partition images (.img) in a ZIP instead of a flashable ROM"
    echo "      --incremental-from <ver>"
    echo "                             Build an incremental OTA from a previous version saved in TARGET_FILES"
    echo "  -h, --help                 Show this help"
    echo ""
    echo "Supported devices:"
    ls LumiROM/Devices 2>/dev/null || echo "  (run this script from the repository root)"
    echo ""
    echo "Examples:"
    echo "  bash build_local.sh -s SM-A325F -c EUX -i 353117555323497"
    echo "  bash build_local.sh -s SM-A225F -c INS -i 358212589089183 --no-ai --img-zip"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -s|--stock) STOCK_DEVICE="${2:?Option $1 requires a value}"; shift 2 ;;
        -t|--target) TARGET_DEVICE="${2:?Option $1 requires a value}"; shift 2 ;;
        -c|--csc) TARGET_CSC="${2:?Option $1 requires a value}"; shift 2 ;;
        -i|--imei) TARGET_IMEI="${2:?Option $1 requires a value}"; shift 2 ;;
        -m|--maintainer) LUMIROM_MAINTAINER="${2:?Option $1 requires a value}"; shift 2 ;;
        --no-mods) USE_MODS="false"; shift ;;
        --no-ai) USE_GALAXY_AI="false"; shift ;;
        --bpf-legacy) USE_UI_8_TETHERING_APEX="true"; shift ;;
        --img-zip) ZIP_IMG="true"; shift ;;
        --incremental-from) INCREMENTAL_FROM="${2:?Option $1 requires a value}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; echo ""; usage; exit 1 ;;
    esac
done

# Interactive wizard for missing values
# A346B imei = 353117555323497
# A245F imei = 358212589089183

if [ -z "$STOCK_DEVICE" ]; then
    echo "Supported devices:"
    ls LumiROM/Devices
    read -rp "Stock device (SM-XXXXX): " STOCK_DEVICE
fi

if [ -z "$TARGET_CSC" ]; then
    read -rp "CSC/Region (3 letters, e.g. DBT): " TARGET_CSC
fi

if [ -z "$TARGET_IMEI" ]; then
    echo "Tip: example IMEIs for each base device are listed above."
    read -rp "IMEI of the base device (15 digits): " TARGET_IMEI
fi

if [ -z "$LUMIROM_MAINTAINER" ]; then
    read -rp "Maintainer name (GitHub or Telegram username): " LUMIROM_MAINTAINER
fi

source scripts/firmware/FW.sh

if [ -z "$TARGET_DEVICE" ]; then
    TARGET_DEVICE=$(GET_BASE_DEVICE "$STOCK_DEVICE") || exit 1
fi

source scripts/utils/validation.sh
VALIDATION

# --- System Environment Variables ---
export OUTPUT_FILESYSTEM="erofs"
export LUMIROM_VERSION="8.6.4"
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
source scripts/utils/logging.sh
initialize_logs "$STOCK_DEVICE" "$TARGET_DEVICE" "$TARGET_CSC" "$TARGET_IMEI" "$LUMIROM_VERSION" "$USE_MODS" "$USE_GALAXY_AI" "$USE_UI_8_TETHERING_APEX" "$OUTPUT_FILESYSTEM" "$LUMIROM_MAINTAINER"

# --- Start of Process ---

# Give execution permissions
log_section "Setting up permissions"
find scripts -name "*.sh" -exec chmod +x {} +
chmod +x bin/MergeOTA/MergeAll.sh
chmod +x bin/erofs-utils/extract.erofs
chmod +x bin/erofs-utils/mkfs.erofs
chmod +x bin/lp/*
log_message "Permissions set successfully"

log_section "Installing required packages"
source scripts/utils/install_packages.sh
UBUNTU_PACKAGES 2>&1 | tee -a "$LOG_FILE"
PYTHON_PACKAGES 2>&1 | tee -a "$LOG_FILE"

log_section "Setting up directories"
mkdir -p "$WORK_DIR"
bash scripts/utils/setup_directories.sh FIRMWARE WORK OUT ROM TMP IMGs TARGET_FILES LOGS 2>&1 | tee -a "$LOG_FILE"

log_section "Checking the environment"
source scripts/firmware/local_official.sh 
IS_LOCAL_OFFICIAL >> "$LOG_FILE" 2>&1

log_section "Downloading Firmware"
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

source scripts/features/LumiROM.sh
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
    source scripts/features/Mods.sh
    ADD_MODS "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"

    log_section "Adding Cloudy OTA Helper"
    source scripts/features/Cloudy.sh
    ADD_CLOUDY "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
fi

if [ "$USE_GALAXY_AI" = "true" ]; then
    log_section "Adding Galaxy AI"
    source scripts/features/Galaxy_AI.sh
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
source scripts/features/Knox_script.sh
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
source scripts/features/LumiROM.sh 2>&1 | tee -a "$LOG_FILE"
BUILD_IMG "$FIRM_DIR" "$OUTPUT_FILESYSTEM" "$OUT_DIR" 2>&1 | tee -a "$LOG_FILE"

source scripts/package/zip_creation.sh

if [ "$ZIP_IMG" = "true" ]; then
    log_section "Creating IMG ZIP"
    IMG_ZIP_CREATION "$OUT_DIR" 2>&1 | tee -a "$LOG_FILE"
else
    IMG_TO_BROTLI "$OUT_DIR" "TMP" 2>&1 | tee -a "$LOG_FILE"

    log_section "Creating flashable ZIP"
    UPDATE_ZIP_SCRIPT "$FIRM_DIR" 2>&1 | tee -a "$LOG_FILE"
    FLASHABLE_ZIP_CREATION 2>&1 | tee -a "$LOG_FILE"

    log_section "Saving target files"
    CREATE_TARGET_FILES "$PWD/TARGET_FILES/LumiROM_TARGET_${LUMIROM_VERSION}_${STOCK_DEVICE}.zip" 2>&1 | tee -a "$LOG_FILE"

    if [ -n "$INCREMENTAL_FROM" ]; then
        log_section "Building incremental OTA"
        source scripts/package/build_incremental_ota.sh
        BUILD_INCREMENTAL_OTA "$PWD/TARGET_FILES/LumiROM_TARGET_${INCREMENTAL_FROM}_${STOCK_DEVICE}.zip" "$OUT_DIR" 2>&1 | tee -a "$LOG_FILE"
    fi
fi

log_message "Cleaning up temporary directories..."
rm -rf ./OUT/ ./TMP/ ./WORK/ ./FIRMWARE/ 2>&1 | tee -a "$LOG_FILE"

log_message "✓ LumiROM $LUMIROM_VERSION for $STOCK_DEVICE is ready!"
log_message "✓ You can find it in the ROM folder"

# Generate build summary and finalize logs
finalize_logs "$START_TIME"
