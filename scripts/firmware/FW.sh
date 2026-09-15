#!/bin/bash

source scripts/utils/bash_colors.sh

# Load logging functions if available
if [ -f "scripts/utils/logging.sh" ]; then
    source scripts/utils/logging.sh
fi

GET_BASE_DEVICE() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <STOCK_DEVICE>"
        return 1
    fi

    case "$1" in
        SM-A325F|SM-A325M|SM-M325F)
            echo "SM-A346B"
            ;;
        SM-A225F|SM-A225M|SM-E225F|SM-M225F|SM-A226B)
            echo "SM-A245F"
            ;;
        *)
            echo "${RED}Error:${RESET} No base device found for $1." >&2
            return 1
            ;;
    esac
}

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
    aria2c -x 16 -k 1M -d "$DOWN_DIR" -o "vendor.img" --allow-overwrite=true --auto-file-renaming=false --console-log-level=error "https://github.com/LumiROM/VendorsForMTKG80/releases/download/${STOCK_DEVICE}_latest/vendor.img" || return 1
    
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

    # Correct owner and permissions of extracted ext4 partitions
    sudo chown -R $USER:$USER "$FIRM_DIR/vendor/"
    sudo chown -R $USER:$USER "$FIRM_DIR/config/"
    sudo chmod -R 755 "$FIRM_DIR/config/"
}
GEN_FS_CONFIG() {
    local EXTRACTED_FIRM_DIR="${1%/}"

    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [[ -d "$ROOT" ]] || continue
        PARTITION=$(basename "$ROOT")
        [[ "$PARTITION" == "config" ]] && continue

        local FS_CONFIG="$EXTRACTED_FIRM_DIR/config/${PARTITION}_fs_config"
        [[ ! -f "$FS_CONFIG" ]] && touch "$FS_CONFIG"

        echo "${YELLOW}--- Synchronizing $PARTITION ---${RESET}"

        if [[ "$PARTITION" == "vendor" ]]; then
            local TMP_CLEAN=$(mktemp)
            awk '{
                if (NF < 4) next;
                # strip leading "/" from the path (mkfs does it too), keep the root as-is
                if ($1 != "/") gsub(/^\//, "", $1);
                # normalize modes like 0755 -> 755
                if (length($4) == 4 && substr($4, 1, 1) == "0") $4 = substr($4, 2);
                line = $1 " " $2 " " $3 " " $4;
                for (i = 5; i <= NF; i++)
                    if ($i ~ /^capabilities=/) line = line " " $i;
                print line;
            }' "$FS_CONFIG" | sort -u > "$TMP_CLEAN"
            mv "$TMP_CLEAN" "$FS_CONFIG"
        fi

        # Ensure the root entry exists for every partition
        local ROOT_UID_GID="0 0"
        [[ "$PARTITION" == "vendor" ]] && ROOT_UID_GID="0 2000"
        if ! grep -qE '^/ ' "$FS_CONFIG"; then
            echo "/ $ROOT_UID_GID 0755" >> "$FS_CONFIG"
        fi

        # The tree may be root-owned (real build) or user-owned (test); use sudo if available
        local FIND_CMD="find"
        if sudo -n true 2>/dev/null; then FIND_CMD="sudo find"; fi

        local TMP_EXISTING=$(mktemp)
        awk '{print $1}' "$FS_CONFIG" > "$TMP_EXISTING"

        local ADDED=0
        while IFS= read -r ENTRY; do
            [[ -z "$ENTRY" ]] && continue

            local REL_PATH="${ENTRY#$PARTITION/}"
            [[ -z "$REL_PATH" ]] && continue

            if grep -Fqx "$ENTRY" "$TMP_EXISTING" 2>/dev/null; then
                continue
            fi

            local UID_GID_MODE
            UID_GID_MODE=$(stat -c '%u %g %a' "$ROOT/$REL_PATH" 2>/dev/null) || continue

            local CAPS=""
            local CAP
            CAP=$(GET_FILE_CAPABILITIES "$ROOT/$REL_PATH") || true
            [[ -n "$CAP" ]] && CAPS=" $CAP"

            echo "  ${GREEN}[+]${RESET} Adding: $ENTRY ($UID_GID_MODE${CAPS})"
            echo "$ENTRY $UID_GID_MODE$CAPS" >> "$FS_CONFIG"
            echo "$ENTRY" >> "$TMP_EXISTING"
            ADDED=$((ADDED + 1))
        done < <($FIND_CMD "$ROOT" -mindepth 1 -printf "$PARTITION/%P\n")

        rm "$TMP_EXISTING"
        echo "${YELLOW}  [+] $ADDED new entries added for $PARTITION${RESET}"
    done
}

GET_FILE_CAPABILITIES() {
    command -v getfattr &>/dev/null || { echo ""; return 1; }
    command -v od &>/dev/null || { echo ""; return 1; }

    local FILE="$1"
    local RAW
    RAW=$(getfattr -n security.capability --only-values -h "$FILE" 2>/dev/null) || { echo ""; return 1; }
    [[ -z "$RAW" ]] && { echo ""; return 1; }

    # 5 x uint32 little-endian (magic_etc, permitted[0], permitted[1], inheritable[0], inheritable[1])
    mapfile -t VALS < <(printf '%s' "$RAW" | od -An -v -tu4 | tr -s ' ' '\n')
    [[ "${#VALS[@]}" -lt 5 ]] && { echo ""; return 1; }

    local R1="${VALS[1]}" R2="${VALS[2]}" R3="${VALS[3]}"
    local CAP
    if [[ "$R1" -gt 65535 ]]; then
        CAP=$(printf '%04x%04x' "$R3" "$R1" | sed 's/^0*//')
    else
        CAP=$(printf '%04x%04x%04x' "$R3" "$R2" "$R1" | sed 's/^0*//')
    fi
    [[ -z "$CAP" ]] && CAP="0"
    echo "capabilities=0x${CAP}"
}

GEN_FILE_CONTEXTS() {
    local EXTRACTED_FIRM_DIR="${1%/}"

    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [[ -d "$ROOT" ]] || continue
        PARTITION=$(basename "$ROOT")
        [[ "$PARTITION" == "config" ]] && continue

        local FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/${PARTITION}_file_contexts"
        [[ ! -f "$FILE_CONTEXTS" ]] && touch "$FILE_CONTEXTS"

        echo "${YELLOW}--- Syncing contexts for: $PARTITION ---${RESET}"

        # *_exec types declared in the policy (for new binaries)
        local TARGET_VER="${SELINUX_TARGET_VER:-31}"
        local TMP_EXEC_TYPES=$(mktemp)
        find "$EXTRACTED_FIRM_DIR" -name "*.cil" -not -name "*_genfs_*" \( \
            -path "*/mapping/${TARGET_VER}.*" -o -not -path "*/mapping/*" \) -type f 2>/dev/null \
            -exec grep -hoP '^\(\s*type\s+\K[a-zA-Z0-9_-]+' {} + 2>/dev/null | grep "_exec$" | sort -u > "$TMP_EXEC_TYPES"

        # Lookup: unescaped path -> context
        local TMP_LOOKUP=$(mktemp)
        sed -e 's/\\\././g' -e 's/\\\+/+/g' -e 's/\\\[/[/g' -e 's/\\\]/]/g' -e 's/\\\*/*/g' \
            "$FILE_CONTEXTS" | awk '{print $1 "\t" $2}' > "$TMP_LOOKUP"

        # Anchored (full-match) patterns for the coverage test
        local TMP_PATTERNS=$(mktemp)
        awk '{print "^" $1 "$"}' "$FILE_CONTEXTS" > "$TMP_PATTERNS"

        # All tree paths
        local FIND_CMD="find"
        if sudo -n true 2>/dev/null; then FIND_CMD="sudo find"; fi
        local TMP_ALL=$(mktemp)
        $FIND_CMD "$ROOT" -mindepth 1 \( -type f -o -type d \) -printf "/$PARTITION/%P\n" | sort -u > "$TMP_ALL"

        # Uncovered = all - those matching any anchored pattern
        local TMP_COVERED=$(mktemp)
        grep -E -f "$TMP_PATTERNS" "$TMP_ALL" 2>/dev/null > "$TMP_COVERED" || true
        local TMP_UNCOVERED=$(mktemp)
        grep -vxF -f "$TMP_COVERED" "$TMP_ALL" > "$TMP_UNCOVERED" || true

        local ADDED=0
        while IFS= read -r PATH_ENTRY; do
            [[ -z "$PATH_ENTRY" ]] && continue

            local FULL_PATH="$ROOT/${PATH_ENTRY#/$PARTITION/}"

            # Walk-up to the nearest ancestor that has a context
            local CONTEXT=""
            local ANCESTOR="$PATH_ENTRY"
            while [[ "$ANCESTOR" != "/" && "$ANCESTOR" != "/$PARTITION" && -z "$CONTEXT" ]]; do
                ANCESTOR="${ANCESTOR%/*}"
                CONTEXT=$(grep -F -m1 -e "$ANCESTOR"$'\t' "$TMP_LOOKUP" 2>/dev/null | cut -f2) || true
            done

            # Fallback to the partition root context
            if [[ -z "$CONTEXT" ]]; then
                CONTEXT=$(grep -F -m1 -e "/$PARTITION"$'\t' "$TMP_LOOKUP" 2>/dev/null | cut -f2) || true
            fi
            [[ -z "$CONTEXT" ]] && CONTEXT="u:object_r:system_file:s0"

            # New executable binary: if the policy declares <name>_exec, use it
            # (only when the ancestor gives a generic file context).
            local BASENAME="${PATH_ENTRY##*/}"
            if [[ -f "$FULL_PATH" && ! -L "$FULL_PATH" && -x "$FULL_PATH" ]] \
                && { [[ "$CONTEXT" == "u:object_r:system_file:s0" ]] || [[ "$CONTEXT" == "u:object_r:vendor_file:s0" ]]; }; then
                if grep -Fxq "${BASENAME}_exec" "$TMP_EXEC_TYPES" 2>/dev/null; then
                    CONTEXT="u:object_r:${BASENAME}_exec:s0"
                fi
            fi

            local ESCAPED_PATH
            ESCAPED_PATH=$(echo "$PATH_ENTRY" | sed -e 's/\./\\\./g' -e 's/+/\\\+/g' -e 's/\[/\\\[/g' -e 's/\]/\\\]/g' -e 's/*/\\\*/g')

            echo "  ${GREEN}[+]${RESET} Context for: $PATH_ENTRY -> $CONTEXT"
            echo "$ESCAPED_PATH $CONTEXT" >> "$FILE_CONTEXTS"
            echo -e "$PATH_ENTRY\t$CONTEXT" >> "$TMP_LOOKUP"
            ADDED=$((ADDED + 1))
        done < "$TMP_UNCOVERED"

        rm "$TMP_EXEC_TYPES" "$TMP_LOOKUP" "$TMP_PATTERNS" "$TMP_ALL" "$TMP_COVERED" "$TMP_UNCOVERED"
        echo "${YELLOW}  [+] $ADDED new entries added for $PARTITION${RESET}"
    done
}

BUILD_IMG() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <FILE_SYSTEM> <OUT_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local FILE_SYSTEM="$2"
	local OUT_DIR="$3"
    local DEVICE_CONFIG="$(pwd)/LumiROM/Devices/${STOCK_DEVICE}/config"
    local OP_LIST="$(pwd)/makerom/dynamic_partitions_op_list"

    if [[ -f "$DEVICE_CONFIG" ]]; then
        local SUPER_SIZE=$(grep "STOCK_SUPER_SIZE" "$DEVICE_CONFIG" | cut -d'=' -f2 | tr -d '[:space:]')
        
        # Update the super size on the list according to the device
        if [[ -n "$SUPER_SIZE" && -f "$OP_LIST" ]]; then
            echo "${GREEN}Updating super size on op_list: $SUPER_SIZE bytes${RESET}"
            sed -i "s/^add_group samsung_dynamic_partitions .*/add_group samsung_dynamic_partitions $SUPER_SIZE/" "$OP_LIST"
        else
            echo "${RED}Warning: STOCK_SUPER_SIZE hasn't been found on $DEVICE_CONFIG${RESET}"
        fi
    else
        echo "${RED}Error: config file not found${RESET}"
    fi


    AUTO_FIX_SELINUX "$EXTRACTED_FIRM_DIR"

    GEN_FS_CONFIG "$EXTRACTED_FIRM_DIR"
	GEN_FILE_CONTEXTS "$EXTRACTED_FIRM_DIR"

    for PART in "$EXTRACTED_FIRM_DIR"/*; do
        [[ -d "$PART" ]] || continue    
        PARTITION="$(basename "$PART")"
        [[ "$PARTITION" == "config" ]] && continue 

        (
            local SRC_DIR="$EXTRACTED_FIRM_DIR/$PARTITION"
            local OUT_IMG="$OUT_DIR/${PARTITION}.img"
            local FS_CONFIG="$EXTRACTED_FIRM_DIR/config/${PARTITION}_fs_config"
            local FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/${PARTITION}_file_contexts"

            echo ""
            [[ -f "$FS_CONFIG" ]] || { echo "Warning: $FS_CONFIG missing, skipping $PARTITION"; exit 0; }
            [[ -f "$FILE_CONTEXTS" ]] || { echo "Warning: $FILE_CONTEXTS missing, skipping $PARTITION"; exit 0; }

            sudo env LC_ALL=C sort -u "$FILE_CONTEXTS" -o "$FILE_CONTEXTS"
            sudo env LC_ALL=C sort -u "$FS_CONFIG" -o "$FS_CONFIG"

            echo "${YELLOW}Building $FILE_SYSTEM image: $OUT_IMG${RESET}"
            # Building (mkfs, size, lost+found, map) is handled by build_fs_image.sh
            sudo "$(pwd)/scripts/build_fs_image.sh" "$FILE_SYSTEM" \
                --force \
                --output "$OUT_IMG" \
                --partition-name "$PARTITION" \
                "$SRC_DIR" "$FILE_CONTEXTS" "$FS_CONFIG"
            touch "$OUT_DIR/$PARTITION.map"
        ) &
    done

    wait

    # Updates the list sequentially to avoid race conditions
    for PART in "$EXTRACTED_FIRM_DIR"/*; do
        [[ -d "$PART" ]] || continue    
        PARTITION="$(basename "$PART")"
        local OUT_IMG="$OUT_DIR/${PARTITION}.img"
        if [[ -f "$OUT_IMG" && -f "$OP_LIST" ]]; then
            local ACTUAL_SIZE=$(stat -c%s "$OUT_IMG")
            echo "${GREEN}Updating size of $PARTITION in op_list: $ACTUAL_SIZE bytes${RESET}"
            sed -i "s/^resize $PARTITION .*/resize $PARTITION $ACTUAL_SIZE/" "$OP_LIST"
        fi
    done
}

IMG_TO_BROTLI() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <IMG_DIR> <TMP_DIR>"
        return 1
    fi

    local IMG_DIR="$1"
    local TMP_DIR="$2"
    local IMG2SDAT_BIN="$(pwd)/bin/img2sdat/img2sdat"

    mkdir -p "$TMP_DIR"

    # Check if img2sdat binary exists
    if [[ ! -f "$IMG2SDAT_BIN" ]]; then
        echo "${RED}Error: img2sdat binary not found at $IMG2SDAT_BIN${RESET}"
        return 1
    fi

    chmod +x "$IMG2SDAT_BIN"

    # This is for compressing to .new.dat
    echo "${BLUE}=== Converting IMG to SDAT ===${RESET}"

    for f in "$IMG_DIR"/*.img; do
        [[ -f "$f" ]] || continue
        PARTITION="$(basename "$f" .img)"

        (
            echo "${GREEN}Converting $PARTITION.img...${RESET}"
            "$IMG2SDAT_BIN" -o "$TMP_DIR" "$f" > /dev/null 2>&1
            touch "$TMP_DIR/$PARTITION.patch.dat"
            echo "${GREEN}Created patch.dat for $PARTITION${RESET}"
        ) &
    done

    wait

    # Compress it to .new.dat.br to make later a .zip file
    echo ""
    echo "${BLUE}=== Compressing DAT files with Brotli (Parallel) ===${RESET}"

    local JOBS=4 # Set to match vCPUs
    for DAT in "$TMP_DIR"/*.new.dat; do
        [[ -f "$DAT" ]] || continue
        PARTITION="$(basename "$DAT" .new.dat)"
        OUT_FILE="$TMP_DIR/$PARTITION.new.dat.br"

        (
            echo "${YELLOW}Compressing $PARTITION.new.dat...${RESET}"
            brotli -f -q 1 --output="$OUT_FILE" "$DAT"
            echo "${GREEN}Finished $PARTITION.new.dat.br${RESET}"
        ) &

        # Limit concurrent jobs
        while [ $(jobs -r | wc -l) -ge "$JOBS" ]; do
            sleep 1
        done
    done

    wait
    echo ""
    echo "${GREEN}All partitions converted and compressed successfully.${RESET}"
}
