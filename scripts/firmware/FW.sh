#!/bin/bash

source scripts/utils/bash_colors.sh

# Load logging functions if available
if [ -f "scripts/utils/logging.sh" ]; then
    source scripts/utils/logging.sh
fi

CHECK_FIRMWARE_IMAGES() {
    if [ "$#" -lt 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIR> <PARTITION_LIST>"
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
        echo "${GREEN}✅ All firmware images found in cache!${RESET}"
        return 0
    else
        echo "${YELLOW}⚠️  Some firmware images are missing.${RESET}"
        return 1
    fi
}

CLEAR_FIRMWARE_CACHE() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIR>"
        return 1
    fi

    local FIRM_DIR="$1"
    echo "${YELLOW}Clearing firmware cache...${RESET}"
    rm -rf "$FIRM_DIR"
    mkdir -p "$FIRM_DIR"
    echo "${GREEN}Cache cleared.${RESET}"
}

CHECK_VENDOR_IMAGE() {
    if [ "$#" -lt 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIR>"
        return 1
    fi

    local FIRM_DIR="$1"

    if [ ! -d "$FIRM_DIR" ]; then
        return 1
    fi

    if [ -f "$FIRM_DIR/vendor.img" ]; then
        echo "${GREEN}✅ Vendor image found in cache!${RESET}"
        return 0
    else
        echo "${YELLOW}⚠️  Vendor image not found in cache.${RESET}"
        return 1
    fi
}

DOWNLOAD_FIRMWARE() {
    if [ "$#" -lt 4 ]; then
        echo "Usage: ${FUNCNAME[0]} <MODEL> <CSC> <IMEI> <DOWNLOAD_DIRECTORY> [VERSION]"
        return 1
    fi

    local MODEL="$1"
    local CSC="$2"
    local IMEI="$3"
    local DOWN_DIR="${4}/$MODEL"

    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

        echo "${BLUE}======================================${RESET}"
        echo "${BLUE}       Samsung FW Downloader${RESET}"
        echo "${BLUE}======================================${RESET}"
        echo "${PURPLE}MODEL:${RESET} $MODEL | ${PURPLE}CSC:${RESET} $CSC"

        # --- Step 1: Determine Version ---
        if [ -n "$VERSION" ]; then
            echo "- ✅ Downloading provided version: $VERSION"
        else
            echo "- Fetching latest firmware..."

            VERSION=$(python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" checkupdate 2>&1)

            if [ $? -ne 0 ] || [ -z "$VERSION" ]; then
                echo "- ⛔️ MODEL/CSC/IMEI not valid or no update found."
                echo "- Error: $VERSION"
                return 1
            fi

            echo "- ✅ Latest version found: $VERSION"
            if [ -n "$GITHUB_ENV" ]; then
                echo "VERSION=$VERSION" >> "$GITHUB_ENV"
            fi
        fi

        # --- Step 2: Download Firmware ---
        python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" download -O "$DOWN_DIR"
        if [ $? -ne 0 ]; then
            echo "⛔️ Download failed. Check IMEI/MODEL/CSC."
            exit 1
        fi

        find "$DOWN_DIR" -type f -name "*.zip.enc*" -delete

        # --- Show Firmware Info ---
        local file_size=$(du -m "${DOWN_DIR}"/${MODEL}_*_fac.zip 2>/dev/null | cut -f1)
        echo "Firmware Size: ${file_size} MB"

        mv "${DOWN_DIR}"/${MODEL}_*_fac.zip "IMGs/${MODEL}.zip"
        rm -rf "${DOWN_DIR}/${MODEL}"
}

DOWNLOAD_FIRMWARE_LUMI() {
    if [ "$#" -lt 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local DOWN_DIR="${1}"
    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    if [[ "$STOCK_DEVICE" == "SM-A325F" || "$STOCK_DEVICE" == "SM-A325M" || "$STOCK_DEVICE" == "SM-M325F" ]]; then
        export TARGET_DEVICE="SM-A346B"
        echo "${YELLOW}Downloading firmware for${RESET} ${TARGET_DEVICE}"
        aria2c -x 16 -d "${DOWN_DIR}/${TARGET_DEVICE}" -o "${TARGET_DEVICE}.zip" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://huggingface.co/buckets/LuminousJD418/LumiROM/resolve/OneUI8.5/FW/SM-A346B/SM-A346B.zip?download=true" || return 1
    elif [[ "$STOCK_DEVICE" == "SM-A225F" || "$STOCK_DEVICE" == "SM-A225M" || "$STOCK_DEVICE" == "SM-E225F" || "$STOCK_DEVICE" == "SM-M225F" || "$STOCK_DEVICE" == "SM-A226B" ]]; then
        export TARGET_DEVICE="SM-A245F"
        echo "${YELLOW}Downloading firmware for${RESET} ${TARGET_DEVICE}"
        aria2c -x 16 -d "${DOWN_DIR}/${TARGET_DEVICE}" -o "${TARGET_DEVICE}.zip" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://huggingface.co/buckets/LuminousJD418/LumiROM/resolve/OneUI8.5/FW/SM-A245F_4_20260220151250_g2yvot48sr_fac_A245FXXSBEZB5_A245FOXMBEZB5_A245FXXSBEZB5_A245FXXSBEZB5_SEK.zip?download=true" || return 1
    fi

    # Cleanup any leftover .aria2 control files
    wait
    find "${DOWN_DIR}/${TARGET_DEVICE}" -name "*.aria2" -exec rm -f {} +
}

DOWNLOAD_OTA() {
    if [ "$#" -lt 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local DOWN_DIR="${1}"
    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    echo "${YELLOW}Downloading OTA${RESET}"
    if [ -d "FIRMWARE/SM-A346B" ]; then
        aria2c -x 16 -d "$DOWN_DIR" -o "OTA_SM-A346B.zip" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://huggingface.co/buckets/LuminousJD418/LumiROM/resolve/OneUI8.5/OTA/SM-A346BOMB.zip?download=true" || return 1
    elif [ -d "FIRMWARE/SM-A245F" ]; then
        aria2c -x 16 -d "$DOWN_DIR" -o "OTA_SM-A245F.zip" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://huggingface.co/buckets/LuminousJD418/LumiROM/resolve/OneUI8.5/OTA/SM-A245F_BOMB.zip?download=true" || return 1
    fi
    # Cleanup any leftover .aria2 control files
    wait
    find "$DOWN_DIR" -name "*.aria2" -exec rm -f {} +
}

MERGE_OTA() {
    if [ "$#" -lt 3 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIR> <OTA_DIR> <IMG_DIR>"
        return 1
    fi

    local FW_DIR="$1"
    local OTA_DIR="$2"
    local IMG_DIR="$3"

    mv "${FW_DIR}/${TARGET_DEVICE}/${TARGET_DEVICE}.zip" ./bin/MergeOTA/
    mv "${OTA_DIR}/OTA_${TARGET_DEVICE}.zip" ./bin/MergeOTA/
    
    echo "${YELLOW}Running MergeAll.sh...${RESET}"
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
}

DOWNLOAD_VENDOR() {
    if [ "$#" -lt 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local DOWN_DIR="${1}"

    echo "${YELLOW}Downloading vendor for${RESET} ${STOCK_DEVICE}"
    aria2c -x 16 -k 1M -d "$DOWN_DIR" -o "vendor.img" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://github.com/Luminous418/VendorsForMTKG80/releases/download/${STOCK_DEVICE}_latest/vendor.img" || return 1
    
    # Cleanup any leftover .aria2 control files
    wait
    find "$DOWN_DIR" -name "*.aria2" -exec rm -f {} +
}

EXTRACT_FIRMWARE() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi

    local FIRM_DIR="$1"

    echo "Extracting downloaded firmware."

	if [ ! -d "$FIRM_DIR" ]; then
        echo "- Directory not found: $FIRM_DIR"
        exit
    fi

    # ---- ZIP ----
    for file in "$FIRM_DIR"/*.zip; do
        [ -e "$file" ] || continue

        echo "Extracting zip: $(basename "$file")"
        7z x -y -bd -bsp1 -o"$FIRM_DIR" "$file"

        rm -f "$file"
    done

    # remove unwanted archives before extraction
    rm -f "$FIRM_DIR"/BL_*.tar.md5
    rm -f "$FIRM_DIR"/CP_*.tar.md5
    rm -f "$FIRM_DIR"/CSC_*.tar.md5
    rm -f "$FIRM_DIR"/HOME_CSC_*.tar.md5
	rm -f "$FIRM_DIR"/USERDATA_*.tar.md5

    # Extract XZ 
    for file in "$FIRM_DIR"/*.xz; do
        [ -e "$file" ] || continue

        echo "Extracting xz: $(basename "$file")"
        7z x -y -bd -bsp1 -o"$FIRM_DIR" "$file"

        rm -f "$file"
    done

    # Rename .MD5 to .TAR
    for file in "$FIRM_DIR"/*.md5; do
        [ -e "$file" ] || continue

        mv -- "$file" "${file%.md5}"
    done

    # UN-TAR
    for file in "$FIRM_DIR"/*.tar; do
        [ -e "$file" ] || continue

        echo "Extracting tar: $(basename "$file")"

        tar -xf "$file" -C "$FIRM_DIR"
    done

    # LZ4 Extraction
    echo "Extracting super.img.lz4"
    find "$FIRM_DIR" -type f -name "*.lz4" ! -name "super.img.lz4" -delete
    lz4 -d "$FIRM_DIR/super.img.lz4" "$FIRM_DIR/super.img" 
    echo "Firmware Extraction complete."
}

EXTRACT_SUPER_IMG() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi

    local IMGS_DIR="$1"

    if [ -f "$IMGS_DIR/super.img" ]; then
    
        echo "Extracting super.img"
		echo "Converting to raw super.img"
        simg2img "$IMGS_DIR/super.img" "$IMGS_DIR/super_raw.img"
        rm -f "$IMGS_DIR/super.img"
        mv -f "$IMGS_DIR/super_raw.img" "$IMGS_DIR/super.img"


        echo "- Extracting partitions from super.img"
        ./bin/lp/lpunpack "$IMGS_DIR/super.img" "$IMGS_DIR" || return 1
        rm -f "$IMGS_DIR/super.img"
        # Delete the vendor as it is from the firmware and not from the stock device
        rm -f "$IMGS_DIR/vendor.img"

        echo "- super.img extraction complete"

    else
        echo "- No super.img found."
    fi
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
    echo "${YELLOW}Preparing partitions.${RESET}"

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
            echo "${GREEN}- Keeping:${RESET} $item"
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

	echo "${YELLOW}Extracting images from $IMG_DIR${RESET}"
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
                    echo "$imgfile Detected ${BLUE}ext4${RESET}. Size: $IMG_SIZE bytes."
                    echo "${YELLOW}Extracting $imgfile in $FIRM_DIR/$partition${RESET}"
                    echo "${YELLOW}You will need sudo for extract ext4 images.${RESET}"
                    sudo python3 $(pwd)/bin/py_scripts/imgextractor.py "$imgfile" "$FIRM_DIR" > /dev/null 2>&1
                    ;;
                EROFS)
                    echo ""
                    IMG_SIZE=$(stat -c%s -- "$imgfile")
                    echo "$imgfile Detected ${BLUE}$fstype${RESET}. Size: $IMG_SIZE bytes."
                    echo "${YELLOW}Extracting $imgfile in $FIRM_DIR/$partition${RESET}"
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