#!/bin/bash

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

    if [[ "$STOCK_DEVICE" == "SM-A325F" || "$STOCK_DEVICE" == "SM-A325M" || "$STOCK_DEVICE" == "SM-M325F" ]]; then
        echo -e "======================================"
        echo -e "       Samsung FW Downloader"
        echo -e "======================================"
        echo -e "MODEL: $MODEL | CSC: $CSC"

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

    # This will be temporary
    elif [[ "$STOCK_DEVICE" == "SM-A225F" || "$STOCK_DEVICE" == "SM-A225M" || "$STOCK_DEVICE" == "SM-E225F" || "$STOCK_DEVICE" == "SM-M225F" || "$STOCK_DEVICE" == "SM-A226B" ]]; then
        echo "TARGET_DEVICE=SM-A245F" >> $GITHUB_ENV
        export TARGET_DEVICE="SM-A245F"
        aria2c -x 16 -d "./FIRMWARE/${TARGET_DEVICE}" -o "${TARGET_DEVICE}_FW.zip" --allow-overwrite=true --auto-file-renaming=false "https://huggingface.co/buckets/Zears14/lumifiles/resolve/OneUI8.5/A24/SM-A245F_4_20260220151250_g2yvot48sr_fac_A245FXXSBEZB5_A245FOXMBEZB5_A245FXXSBEZB5_A245FXXSBEZB5_SEK.zip?download=true" || return 1
        # Cleanup any leftover .aria2 control files after everything finishes
        wait
        find "./FIRMWARE/${TARGET_DEVICE}" -name "*.aria2" -exec rm -f {} +
    fi
}

DOWNLOAD_OTA() {
    if [ "$#" -lt 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local DOWN_DIR="${1}"
    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    echo "Downloading OTA for $MODEL"
    if [[ "$STOCK_DEVICE" == "SM-A325F" || "$STOCK_DEVICE" == "SM-A325M" || "$STOCK_DEVICE" == "SM-M325F" ]]; then
        aria2c -x 16 -d "$DOWN_DIR" -o "OTA_${TARGET_DEVICE}.zip" --allow-overwrite=true --auto-file-renaming=false "https://huggingface.co/buckets/Zears14/lumifiles/resolve/OneUI8.5/OTA/SM-A346BOMB.zip?download=true" || return 1
    elif [[ "$STOCK_DEVICE" == "SM-A225F" || "$STOCK_DEVICE" == "SM-A225M" || "$STOCK_DEVICE" == "SM-E225F" || "$STOCK_DEVICE" == "SM-M225F" || "$STOCK_DEVICE" == "SM-A226B" ]]; then
        aria2c -x 16 -d "$DOWN_DIR" -o "OTA_${TARGET_DEVICE}.zip" --allow-overwrite=true --auto-file-renaming=false "https://huggingface.co/buckets/Zears14/lumifiles/resolve/OneUI8.5/A24/a24.zip?download=true" || return 1
    fi
    # Cleanup any leftover .aria2 control files after everything finishes
    wait
    find "$DOWN_DIR" -name "*.aria2" -exec rm -f {} +
}

MERGE_OTA() {
    if [ "$#" -lt 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FIRMWARE_DIR> <OTA_DIR>"
        return 1
    fi

    local FW_DIR="$1"
    local OTA_DIR="$2"

    mv "${FW_DIR}/${TARGET_DEVICE}/${TARGET_DEVICE}.zip" ./bin/MergeOTA/
    mv "${OTA_DIR}/OTA_${TARGET_DEVICE}.zip" ./bin/MergeOTA/
    
    ./bin/MergeOTA/MergeAll.sh "./bin/MergeOTA/${TARGET_DEVICE}.zip" "./bin/MergeOTA/OTA_${TARGET_DEVICE}.zip"

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
    find ./out/ -mindepth 1 -maxdepth 1 -exec mv {} "${FW_DIR}" \; || return 1
    rmdir ./out/    
}

DOWNLOAD_VENDOR() {
    if [ "$#" -lt 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local DOWN_DIR="${1}"

    echo "Downloading vendor for ${STOCK_DEVICE}"
    aria2c -x 16 -k 1M -d "$DOWN_DIR" -o "vendor.img" --allow-overwrite=true --auto-file-renaming=false "https://github.com/Lumi-ROM/Vendors/releases/download/${STOCK_DEVICE}_latest/vendor.img" &
    
    # Cleanup any leftover .aria2 control files after everything finishes
    wait
    find "$DOWN_DIR" -name "*.aria2" -exec rm -f {} +
}

EXTRACT_FIRMWARE() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi

    local FIRM_DIR="$1"
    local FIRM_FILE="$FIRM_DIR/BASE_FW.zip"

    echo "Extracting downloaded firmware."

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
    echo "Preparing partitions."

    shopt -s nullglob dotglob

    for item in "$EXTRACTED_FIRM_DIR"/*; do
        base=$(basename "$item")

        [[ "$base" == *.img ]] && base="${base%.img}"

        keep_this=0
        for k in "${KEEP[@]}"; do
            [[ "$k" == "$base" ]] && keep_this=1 && break
        done

        if [[ $keep_this -eq 0 ]]; then
            # echo "- Deleting: $item"
            rm -rf -- "$item"
        else
            echo "- Keeping: $item"
        fi
    done

    shopt -u nullglob dotglob
}


EXTRACT_FIRMWARE_IMG() {
    echo ""
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi

	local FIRM_DIR="$1"

	echo "Extracting images from $FIRM_DIR"
    for imgfile in "$FIRM_DIR"/*.img; do
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
                    echo "$imgfile Detected ext4. Size: $IMG_SIZE bytes."
                    echo "Extracting $imgfile in $FIRM_DIR/$partition"
                    sudo python3 $(pwd)/bin/py_scripts/imgextractor.py "$imgfile" "$FIRM_DIR" > /dev/null 2>&1
                    ;;
                EROFS)
                    echo ""
                    IMG_SIZE=$(stat -c%s -- "$imgfile")
                    echo "$imgfile Detected $fstype. Size: $IMG_SIZE bytes."
                    echo "Extracting $imgfile in $FIRM_DIR/$partition"
                    $(pwd)/bin/erofs-utils/extract.erofs -i "$imgfile" -x -f -o "$FIRM_DIR" >/dev/null 2>&1
                    ;;
                *)
                    echo "[$imgfile] Unknown filesystem type ($fstype), skipping"
                    ;;
            esac
        ) &
    done

    wait
    # Remove all original .img
    rm -rf "$FIRM_DIR"/*.img
}