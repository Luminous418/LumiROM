#!/bin/bash

source scripts/bash_colors.sh

# Load logging functions if available
if [ -f "scripts/logging.sh" ]; then
    source scripts/logging.sh
fi

CHECK_FIRMWARE_IMAGES() {
    if [ "$#" -lt 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FIRMWARE_DIR> <PARTITION_LIST>"
        return 1
    fi

    local FIRM_DIR="$1"
    local PARTITION_LIST="$2"

    if [ ! -d "$FIRM_DIR" ]; then
        return 1
    fi

    IFS=',' read -r -a PARTITIONS <<< "$PARTITION_LIST"

    for i in "${!PARTITIONS[@]}"; do
        PARTITIONS[$i]=$(echo "${PARTITIONS[$i]}" | xargs)
    done

    local all_exist=1
    for partition in "${PARTITIONS[@]}"; do
        if [ ! -f "$FIRM_DIR/${partition}.img" ]; then
            all_exist=0
            break
        fi
    done

    if [ $all_exist -eq 1 ]; then
        echo -e "${GREEN}✅ All firmware images found in cache!${RESET}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Some firmware images are missing.${RESET}"
        return 1
    fi
}

CLEAR_FIRMWARE_CACHE() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FIRMWARE_DIR>"
        return 1
    fi

    local FIRM_DIR="$1"
    echo -e "${YELLOW}Clearing firmware cache...${RESET}"
    rm -rf "$FIRM_DIR"
    mkdir -p "$FIRM_DIR"
    echo -e "${GREEN}Cache cleared.${RESET}"
}

CHECK_VENDOR_IMAGE() {
    if [ "$#" -lt 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FIRMWARE_DIR>"
        return 1
    fi

    local FIRM_DIR="$1"

    if [ ! -d "$FIRM_DIR" ]; then
        return 1
    fi

    if [ -f "$FIRM_DIR/vendor.img" ]; then
        echo -e "${GREEN}✅ Vendor image found in cache!${RESET}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Vendor image not found in cache.${RESET}"
        return 1
    fi
}

DOWNLOAD_FIRMWARE() {
    if [ "$#" -lt 4 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <MODEL> <CSC> <IMEI> <DOWNLOAD_DIRECTORY> [VERSION]"
        return 1
    fi

    local MODEL="$1"
    local CSC="$2"
    local IMEI="$3"
    local DOWN_DIR="${4}/$MODEL"
    local VERSION="${5:-}"

    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

        echo -e "${BLUE}======================================${RESET}"
        echo -e "${BLUE}       Samsung FW Downloader${RESET}"
        echo -e "${BLUE}======================================${RESET}"
        echo -e "${PURPLE}MODEL:${RESET} $MODEL | ${PURPLE}CSC:${RESET} $CSC"

        # --- Step 1: Determine Version ---
        if [ -n "$VERSION" ]; then
            echo -e "- ✅ Downloading provided version: $VERSION"
        else
            echo -e "- Fetching latest firmware..."

            VERSION=$(python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" checkupdate 2>&1)

            if [ $? -ne 0 ] || [ -z "$VERSION" ]; then
                echo -e "- ⛔️ MODEL/CSC/IMEI not valid or no update found."
                echo -e "- Error: $VERSION"
                return 1
            fi

            echo -e "- ✅ Latest version found: $VERSION"
            if [ -n "$GITHUB_ENV" ]; then
                echo "VERSION=$VERSION" >> "$GITHUB_ENV"
            fi
        fi

        # --- Step 2: Download Firmware ---
        python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" download -v "$VERSION" -O "$DOWN_DIR"
        if [ $? -ne 0 ]; then
            echo -e "- ⛔️ Download failed. Check IMEI/MODEL/CSC."
            exit 1
        fi

        # --- Step 3: Decrypt Firmware ---
        enc_file=$(find "$DOWN_DIR" -name "*.enc*" | head -n 1)

        if [ -z "$enc_file" ]; then
            echo -e "- ⛔️ No encrypted firmware file found!"
            exit 1
        fi

        python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" decrypt \
            -v "$VERSION" \
            -i "$enc_file" \
            -o "${DOWN_DIR}/${MODEL}.zip" >/dev/null 2>&1

        if [ $? -ne 0 ]; then
            echo -e "- ⛔️ Decryption failed."
            exit 1
        fi

        # --- Show Firmware Info ---
        file_size=$(du -m "${DOWN_DIR}/${MODEL}.zip" | cut -f1)

        echo
        echo -e "- ✅ Firmware decrypted successfully! Firmware Size: ${file_size} MB"
        echo -e "- Saved to: ${DOWN_DIR}/${MODEL}.zip"

        # --- Cleanup ---
        rm -f "$enc_file"
}

DOWNLOAD_FIRMWARE_LUMI() {
    if [ "$#" -lt 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local DOWN_DIR="${1}"
    
    [ -n "$LOG_FILE" ] && log_message "Starting firmware download for $STOCK_DEVICE..."
    
    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    if [[ "$STOCK_DEVICE" == "SM-A325F" || "$STOCK_DEVICE" == "SM-A325M" || "$STOCK_DEVICE" == "SM-M325F" ]]; then
        echo "TARGET_DEVICE=SM-A346B" >> $GITHUB_ENV
        export TARGET_DEVICE="SM-A346B"
        echo -e "${YELLOW}Downloading firmware for${RESET} ${TARGET_DEVICE}"
        [ -n "$LOG_FILE" ] && log_message "Target device: $TARGET_DEVICE - Downloading..."
        aria2c -x 16 -d "${DOWN_DIR}/${TARGET_DEVICE}" -o "${TARGET_DEVICE}.zip" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://huggingface.co/buckets/LuminousJD418/LumiROM/resolve/OneUI8.5/FW/SM-A346B/SM-A346B.zip?download=true" 2>&1 | tee -a "$LOG_FILE" || return 1
    elif [[ "$STOCK_DEVICE" == "SM-A225F" || "$STOCK_DEVICE" == "SM-A225M" || "$STOCK_DEVICE" == "SM-E225F" || "$STOCK_DEVICE" == "SM-M225F" || "$STOCK_DEVICE" == "SM-A226B" ]]; then
        echo "TARGET_DEVICE=SM-A245F" >> $GITHUB_ENV
        export TARGET_DEVICE="SM-A245F"
        echo -e "${YELLOW}Downloading firmware for${RESET} ${TARGET_DEVICE}"
        [ -n "$LOG_FILE" ] && log_message "Target device: $TARGET_DEVICE - Downloading..."
        aria2c -x 16 -d "${DOWN_DIR}/${TARGET_DEVICE}" -o "${TARGET_DEVICE}.zip" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://huggingface.co/buckets/LuminousJD418/LumiROM/resolve/OneUI8.5/FW/SM-A245F_4_20260220151250_g2yvot48sr_fac_A245FXXSBEZB5_A245FOXMBEZB5_A245FXXSBEZB5_A245FXXSBEZB5_SEK.zip?download=true" 2>&1 | tee -a "$LOG_FILE" || return 1
    fi

    # Cleanup any leftover .aria2 control files after everything finishes
    wait
    find "${DOWN_DIR}/${TARGET_DEVICE}" -name "*.aria2" -exec rm -f {} +
    [ -n "$LOG_FILE" ] && log_message "✓ Firmware download completed. TARGET_DEVICE=$TARGET_DEVICE"
}

DOWNLOAD_OTA() {
    if [ "$#" -lt 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local DOWN_DIR="${1}"
    
    [ -n "$LOG_FILE" ] && log_message "Starting OTA download for $TARGET_DEVICE..."
    
    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    echo -e "${YELLOW}Downloading OTA for${RESET} ${TARGET_DEVICE}"
    [ -n "$LOG_FILE" ] && log_message "TARGET_DEVICE at OTA download: $TARGET_DEVICE"
    
    if [[ "$STOCK_DEVICE" == "SM-A325F" || "$STOCK_DEVICE" == "SM-A325M" || "$STOCK_DEVICE" == "SM-M325F" ]]; then
        aria2c -x 16 -d "$DOWN_DIR" -o "OTA_${TARGET_DEVICE}.zip" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://huggingface.co/buckets/LuminousJD418/LumiROM/resolve/OneUI8.5/OTA/SM-A346BOMB.zip?download=true" 2>&1 | tee -a "$LOG_FILE" || return 1
    elif [[ "$STOCK_DEVICE" == "SM-A225F" || "$STOCK_DEVICE" == "SM-E225F" || "$STOCK_DEVICE" == "SM-A226B" ]]; then
        aria2c -x 16 -d "$DOWN_DIR" -o "OTA_${TARGET_DEVICE}.zip" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://huggingface.co/buckets/LuminousJD418/LumiROM/resolve/OneUI8.5/OTA/SM-A245F_BOMB.zip?download=true" 2>&1 | tee -a "$LOG_FILE" || return 1
    fi
    # Cleanup any leftover .aria2 control files after everything finishes
    wait
    find "$DOWN_DIR" -name "*.aria2" -exec rm -f {} +
    [ -n "$LOG_FILE" ] && log_message "✓ OTA download completed"
}

MERGE_OTA() {
    if [ "$#" -lt 3 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FIRMWARE_DIR> <OTA_DIR> <IMG_DIR>"
        return 1
    fi

    local FW_DIR="$1"
    local OTA_DIR="$2"
    local IMG_DIR="$3"

    [ -n "$LOG_FILE" ] && log_message "Starting OTA merge process..."
    [ -n "$LOG_FILE" ] && log_message "TARGET_DEVICE value: $TARGET_DEVICE"
    [ -n "$LOG_FILE" ] && log_message "FW_DIR: $FW_DIR, OTA_DIR: $OTA_DIR, IMG_DIR: $IMG_DIR"

    mv "${FW_DIR}/${TARGET_DEVICE}/${TARGET_DEVICE}.zip" ./bin/MergeOTA/ 2>&1 | tee -a "$LOG_FILE"
    mv "${OTA_DIR}/OTA_${TARGET_DEVICE}.zip" ./bin/MergeOTA/ 2>&1 | tee -a "$LOG_FILE"
    
    [ -n "$LOG_FILE" ] && log_message "Running MergeAll.sh..."
    ./bin/MergeOTA/MergeAll.sh "./bin/MergeOTA/${TARGET_DEVICE}.zip" "./bin/MergeOTA/OTA_${TARGET_DEVICE}.zip" 2>&1 | tee -a "$LOG_FILE"

    # Removes the downloaded firmware and update files
    rm -rf "./bin/MergeOTA/${TARGET_DEVICE}.zip"
    rm -rf "./bin/MergeOTA/OTA_${TARGET_DEVICE}.zip"

    # Removes the not useful partitions
    rm -rf ./out/odm_dlkm.img
    rm -rf ./out/system_dlkm.img
    rm -rf ./out/vendor.img
    rm -rf ./out/vendor_dlkm.img

    # Moves the files to the firmware directory and cleans up
    rmdir "${FW_DIR}/${TARGET_DEVICE}"
    find ./out/ -mindepth 1 -maxdepth 1 -exec mv {} "${IMG_DIR}" \; || return 1
    rmdir ./out/
    
    [ -n "$LOG_FILE" ] && log_message "✓ OTA merge completed successfully"
}

DOWNLOAD_VENDOR() {
    if [ "$#" -lt 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local DOWN_DIR="${1}"

    echo -e "${YELLOW}Downloading vendor for${RESET} ${STOCK_DEVICE}"
    [ -n "$LOG_FILE" ] && log_message "Starting vendor download for $STOCK_DEVICE..."
    aria2c -x 16 -k 1M -d "$DOWN_DIR" -o "vendor.img" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://github.com/Luminous418/VendorsForMTKG80/releases/download/${STOCK_DEVICE}_latest/vendor.img" 2>&1 | tee -a "$LOG_FILE" &
    
    # Cleanup any leftover .aria2 control files after everything finishes
    wait
    find "$DOWN_DIR" -name "*.aria2" -exec rm -f {} +
    [ -n "$LOG_FILE" ] && log_message "✓ Vendor download completed"
}

EXTRACT_FIRMWARE() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi

    local FIRM_DIR="$1"
    local FIRM_FILE="$FIRM_DIR/BASE_FW.zip"

    echo -e "${YELLOW}Extracting downloaded firmware.${RESET}"

    if [ ! -f "$FIRM_FILE" ]; then
        echo "Error: BASE_FW.zip not found in $FIRM_DIR"
        return 1
    fi

    echo "- Extracting zip file."
    find "$FIRM_DIR" -maxdepth 1 -name "*.zip" \
        -exec 7z x -y -bd -o"$FIRM_DIR" {} \; >/dev/null 2>&1
    rm -rf "$FIRM_DIR"/*.zip

    rm -f "$FIRM_FILE"
}


PREPARE_PARTITIONS() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    [[ -z "$EXTRACTED_FIRM_DIR" || ! -d "$EXTRACTED_FIRM_DIR" ]] && {
        echo "Invalid directory: $EXTRACTED_FIRM_DIR"
        return 1
    }

    IFS=',' read -r -a KEEP <<< "$BUILD_PARTITIONS"

    for i in "${!KEEP[@]}"; do
        KEEP[$i]=$(echo "${KEEP[$i]}" | xargs)
    done

    echo ""
    echo -e "${YELLOW}Preparing partitions.${RESET}"

    shopt -s nullglob dotglob

    for item in "$EXTRACTED_FIRM_DIR"/*; do
        base=$(basename "$item")

        [[ "$base" == *.img ]] && base="${base%.img}"

        keep_this=0
        for k in "${KEEP[@]}"; do
            [[ "$k" == "$base" ]] && keep_this=1 && break
        done

        if [[ $keep_this -eq 0 ]]; then
            rm -rf -- "$item"
        else
            echo -e "${GREEN}- Keeping:${RESET} $item"
        fi
    done

    shopt -u nullglob dotglob
}


EXTRACT_FIRMWARE_IMG() {
    echo ""
	if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <IMG_DIRECTORY> <FIRMWARE_DIRECTORY>"
        return 1
    fi

    local IMG_DIR="$1"
	local FIRM_DIR="$2"

	echo -e "${YELLOW}Extracting images from $IMG_DIR${RESET}"
    for imgfile in "$IMG_DIR"/*.img; do
        [ -e "$imgfile" ] || continue

        if [[ "$(basename "$imgfile")" == "boot.img" ]]; then
            continue
        fi

        (
            local partition
            local fstype
            local IMG_SIZE

            partition="$(basename "${imgfile%.img}")"
            fstype=$(file -b $imgfile | awk '{print $1}')

            case "$fstype" in
                Linux)
                    IMG_SIZE=$(stat -c%s -- "$imgfile")
                    echo -e "$imgfile Detected ${BLUE}ext4${RESET}. Size: $IMG_SIZE bytes."
                    echo -e "${YELLOW}Extracting $imgfile in $FIRM_DIR/$partition${RESET}"
                    echo -e "${YELLOW}You will need sudo for extract ext4 images.${RESET}"
                    sudo python3 $(pwd)/bin/py_scripts/imgextractor.py "$imgfile" "$FIRM_DIR" > /dev/null 2>&1
                    ;;
                EROFS)
                    echo ""
                    IMG_SIZE=$(stat -c%s -- "$imgfile")
                    echo -e "$imgfile Detected ${BLUE}$fstype${RESET}. Size: $IMG_SIZE bytes."
                    echo -e "${YELLOW}Extracting $imgfile in $FIRM_DIR/$partition${RESET}"
                    $(pwd)/bin/erofs-utils/extract.erofs -i "$imgfile" -x -f -o "$FIRM_DIR" >/dev/null 2>&1
                    ;;
                *)
                    echo "[$imgfile] Unknown filesystem type ($fstype), skipping"
                    ;;
            esac
        ) &
    done

    wait

    # Correct owner and permissions of the extracted configs
    sudo chown -R $USER:$USER "$FIRM_DIR/config/"
    sudo chmod -R 755 "$FIRM_DIR/config/"
}