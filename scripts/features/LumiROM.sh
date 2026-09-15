#!/bin/bash

export LC_ALL=C

source scripts/utils/bash_colors.sh

source scripts/utils/platform_key.sh

source scripts/features/AppPatches.sh

IS_OFFICIAL() {
    export BUILD_STATUS="UNOFFICIAL"
    export ROM_TAG="🛠️ LumiROM Unofficial Build"

    # A build is official only when it is signed with LumiROM's own platform
    # key (not the AOSP testkey).
    if IS_CUSTOM_PLATFORM_KEY; then
        export BUILD_STATUS="OFFICIAL"
        export ROM_TAG="✨ LumiROM Official Build"
    fi

    if [ -n "$GITHUB_ENV" ]; then
        echo "BUILD_STATUS=$BUILD_STATUS" >> "$GITHUB_ENV"
        echo "ROM_TAG=$ROM_TAG" >> "$GITHUB_ENV"
    fi

    echo "${BLUE}--- $ROM_TAG detected ---${RESET}"
}

CHECK_FILE() {
    if [ ! -f "$1" ]; then
        echo "${RED}[!] File not found:${RESET} $1"
        echo "- Skipping..."
        return 1
    fi
    return 0
}


DISABLE_FBE() {
    local EXTRACTED_FIRM_DIR="$1"
 	
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

    local i

    for i in "$EXTRACTED_FIRM_DIR"/vendor/etc/fstab.mt*; do
    if [ -f $i ]; then
      echo "${YELLOW}Disabling full-based encryption (FBE) for /data...${RESET}"
      echo "- Found $i."
      # If found file-encryption, comments it
      sudo sed -i -e 's/^\([^#].*\)fileencryption=[^,]*\(.*\)$/# &\n\1encryptable\2/g' $i
      echo "${GREEN}Disabled file-encryption on${RESET} $i"
    fi
  done
}


DISABLE_FDE() {
    local EXTRACTED_FIRM_DIR="$1"
 	
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

    local i

    for i in "$EXTRACTED_FIRM_DIR"/vendor/etc/fstab.mt*; do
    if [ -f $i ]; then
      echo "${YELLOW}Disabling full-disk encryption (FDE) for /data...${RESET}"
      echo "- Found $i."
      # If found force-encryption, comments it
      sudo sed -i -e 's/^\([^#].*\)forceencrypt=[^,]*\(.*\)$/# &\n\1encryptable\2/g' $i
      echo "${GREEN}Disabled force-encryption on${RESET} $i"
    fi
  done
}

DELETE_ICCC() {
    local EXTRACTED_FIRM_DIR="$1"
    echo "${YELLOW}Starting wipe...${RESET}"
    # Delete iccc to prevent soft-bootloop

    local targets=(
        "$EXTRACTED_FIRM_DIR/vendor/bin/hw/vendor.samsung.hardware.tlc.iccc@1.0-service"
        "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor.samsung.hardware.tlc.iccc@1.0-service.rc"
        "$EXTRACTED_FIRM_DIR/vendor/etc/vintf/manifest/vendor.samsung.hardware.tlc.iccc@1.0-manifest.xml"
        "$EXTRACTED_FIRM_DIR/vendor/lib64/vendor.samsung.hardware.tlc.iccc@1.0-impl.so"
        "$EXTRACTED_FIRM_DIR/vendor/lib64/vendor.samsung.hardware.tlc.iccc@1.0.so"
    )

    for file in "${targets[@]}"; do
        if [ -e "$file" ] || [ -L "$file" ]; then
            sudo rm -rf "$file"
            echo "${GREEN}Deleted${RESET} $file"
        else
            echo "${RED}[Omitted]${RESET} $file ${RED}not found${RESET}"
        fi
    done

    echo "${GREEN}Wipe iccc completed${RESET}"
}

DEBLOAT_VENDOR() {
    local EXTRACTED_FIRM_DIR="$1"
    echo "${YELLOW}Starting Debloat...${RESET}"

    local targets=(
        "$EXTRACTED_FIRM_DIR/vendor/bin/create_factory_efs_file"
        "$EXTRACTED_FIRM_DIR/vendor/bin/factory"
        "$EXTRACTED_FIRM_DIR/vendor/bin/install-recovery.sh"
        "$EXTRACTED_FIRM_DIR/vendor/etc/factory.ini"
        "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor_flash_recovery.rc"
        "$EXTRACTED_FIRM_DIR/vendor/etc/mmigroup"
        "$EXTRACTED_FIRM_DIR/vendor/etc/recovery-resource.dat"
        "$EXTRACTED_FIRM_DIR/vendor/lib/modules"
        "$EXTRACTED_FIRM_DIR/vendor/lost+found"
        "$EXTRACTED_FIRM_DIR/vendor/recovery-from-boot.p"
        "$EXTRACTED_FIRM_DIR/vendor/res"
    )

    for file in "${targets[@]}"; do
        if [ -e "$file" ] || [ -L "$file" ]; then
            sudo rm -rf "$file"
            echo "${GREEN}Deleted${RESET} $file"
        else
            echo "${RED}[Omitted]${RESET} $file ${RED}not found${RESET}"
        fi
    done

    echo "${GREEN}Vendor debloat completed${RESET}"
}

PATCH_FSTAB_EROFS() {
    local EXTRACTED_FIRM_DIR="$1"
    
    if [ -z "$EXTRACTED_FIRM_DIR" ]; then
        echo "Error: FIRM directory not specified."
        return 1
    fi

    echo "${YELLOW}Applying patches EROFS to fstab...${RESET}"

    local vendor_etc_dir="$EXTRACTED_FIRM_DIR/vendor/etc"
    local fstab_files=()
    mapfile -t fstab_files < <(find "$vendor_etc_dir" -maxdepth 1 -type f -name "fstab.mt*")

    if [ ${#fstab_files[@]} -eq 0 ]; then
        echo "${RED}No fstab files found in${RESET} $vendor_etc_dir"
        return 1
    fi

    local partitions="system system_ext vendor product odm"

    for target in "${fstab_files[@]}"; do
        local fstab_name=$(basename "$target")
        echo "${CYAN}Processing:${RESET} /vendor/etc/$fstab_name"
        
        for part in $partitions; do
            if sudo grep -E -q "^$part[[:space:]]+.*erofs" "$target"; then
                echo "${YELLOW}Skipped:${RESET} Partition $part already contains 'erofs'."
                continue
            fi

            if sudo grep -E -q "^$part[[:space:]]+.*ext4" "$target"; then
                echo "${GREEN}Patching:${RESET} $part (ext4 -> erofs)"
                sudo sed -i -E "/^$part[[:space:]]+.*ext4/ { p; s/ext4/erofs/2; t; s/ext4/erofs/ }" "$target"
            fi
        done
    done

    echo "${GREEN}Done, now${RESET} $STOCK_DEVICE ${GREEN}is EROFS-enabled.${RESET}"
}

INSTALL_FRAMEWORK() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <framework-res.apk>"
        return 1
    fi

    local framework_res_apk="$1"

    # Installing stock overlay
    echo "${YELLOW}Installing Framework...${RESET}"
    java -jar "$APKTOOL" install-framework "$framework_res_apk"
}


DECOMPILE() {
    echo ""
    if [ "$#" -ne 3 ]; then
        echo "Usage: DECOMPILE <APKTOOL_JAR_DIR> <FILE> <DECOMPILE_DIR>"
        return 1
    fi

    local APKTOOL="$1"
    local FILE="$2"
    local DECOMPILE_DIR="$3"
    local BASENAME="$(basename "${FILE%.*}")"
    local OUT="$DECOMPILE_DIR/$BASENAME"

    echo "${YELLOW}Decompiling:${RESET} $FILE"
	rm -rf "$OUT"
    java -jar "$APKTOOL" d -f "$FILE" -o "$OUT"
}


RECOMPILE() {
    echo ""
	if [ "$#" -ne 4 ]; then
        echo "Usage: ${FUNCNAME[0]} <APKTOOL_JAR_DIR> <FRAMEWORK_DIR> <DECOMPILED_DIR> <RECOMPILE_DIR>"
        return 1
    fi

	local APKTOOL="$1"
	local DECOMPILED_DIR="$2"
    local FRAMEWORK_DIR="$3"
    local RECOMPILE_DIR="$4"

    local org_file_name
    org_file_name=$(awk '/^apkFileName:/ {print $2}' "$DECOMPILED_DIR/apktool.yml")
    local name="${org_file_name%.*}"
    local ext="${org_file_name##*.}"
    local built_file="$WORK_DIR/${name}_unsigned.$ext"
    local final_file="$WORK_DIR/$org_file_name"

    echo "${YELLOW}Recompiling:${RESET} $DECOMPILED_DIR"
    java -jar "$APKTOOL" b "$DECOMPILED_DIR" --copy-original -p "$FRAMEWORK_DIR" -o "$built_file"

    # Zipalign
	echo ""
	if [[ "$ext" == "jar" ]]; then
	    echo "Zipaligning: $built_file to $final_file"
        zipalign -v 4 "$built_file" "$final_file" >/dev/null 2>&1
		rm -rf "$built_file" "$DECOMPILED_DIR"
    fi
}

HEX_PATCH() {
    echo ""
	if [ "$#" -ne 3 ]; then
        echo "Usage: ${FUNCNAME[0]} <FILE> <TARGET_VALUE> <REPLACE_VALUE>"
        return 1
    fi

    local FILE="$1"
    local FROM="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
    local TO="$(echo "$3" | tr '[:upper:]' '[:lower:]')"

    [ ! -f "$FILE" ] && { echo "File not found: $FILE"; return 1; }

    xxd -p -c 0 "$FILE" | grep -q "$FROM" || {
        echo "- ${RED}Pattern not found${RESET}: $FROM"
        return 1
    }

    echo "${YELLOW}Patching:${RESET} $FILE"
    echo "- From $FROM to $TO"
    [ -f "$FILE.bak" ] || cp "$FILE" "$FILE.bak"

    xxd -p -c 0 "$FILE" | sed "s/$FROM/$TO/" | xxd -r -p > "$FILE.tmp" &&
    mv "$FILE.tmp" "$FILE"

    xxd -p -c 0 "$FILE" | grep -q "$TO" && {
        echo "- Patch success"
        rm -rf "$FILE.bak"        
        return 0
    }

    echo "${RED}Patch failed, restoring backup${RESET}"
    mv "$FILE.bak" "$FILE"
    return 1
}

PATCH_BT_LIB() {
    echo ""
	if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY> <WORK_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
	local WORK_DIR="$2"
	local BT_LIB_FILE="$WORK_DIR/libbluetooth_jni.so"

    echo "${YELLOW}Patching Bluetooth library...${RESET}"
    # Get libbluetooth_jni.so
    unzip "$EXTRACTED_FIRM_DIR/system/system/apex/com.android.bt.apex" "apex_payload.img" -d "$WORK_DIR"
	debugfs -R "dump /lib64/libbluetooth_jni.so $WORK_DIR/libbluetooth_jni.so" "$WORK_DIR/apex_payload.img"  >/dev/null 2>&1
	rm -rf "$WORK_DIR/apex_payload.img"

    # local associative array (function-scoped)
    declare -A hex=(
        [136]=00122a0140395f01086b00020054 [1136]=00122a0140395f01086bde030014
        [135]=480500352800805228 [1135]=530100142800805228
        [134]=6804003528008052 [1134]=2b00001428008052
        [133]=6804003528008052 [1133]=2a00001428008052
        [132]=........f9031f2af3031f2a41 [1132]=1f2003d5f9031f2af3031f2a48
        [131]=........f9031f2af3031f2a41 [1131]=1f2003d5f9031f2af3031f2a48
        [130]=........f3031f2af4031f2a3e [1130]=1f2003d5f3031f2af4031f2a3e
        [129]=........f4031f2af3031f2ae8030032 [1129]=1f2003d5f4031f2af3031f2ae8031f2a
        [128]=88000034e8030032 [1128]=1f2003d5e8031f2a
        [127]=88000034e8030032 [1127]=1f2003d5e8031f2a
        [126]=88000034e8030032 [1126]=1f2003d5e8031f2a
        [234]=4e7e4448bb [1234]=4e7e4437e0
        [233]=4e7e4440bb [1233]=4e7e4432e0
        [231]=20b14ff000084ff000095ae0 [1231]=00bf4ff000084ff0000964e0
        [230]=18b14ff0000b00254a [1230]=00204ff0000b002554
        [229]=..b100250120 [1229]=00bf00250020
        [228]=..b101200028 [1228]=00bf00200028
        [227]=09b1012032e0 [1227]=00bf002032e0
        [226]=08b1012031e0 [1226]=00bf002031e0
        [225]=087850bbb548 [1225]=08785ae1b548
        [224]=007840bb6a48 [1224]=0078c4e06a48
        [330]=88000054691180522925c81a69000037 [1330]=1f2003d5691180522925c81a1f2003d5
        [329]=88000054691180522925c81a69000037 [1329]=1f2003d5691180522925c81a1f2003d5
        [328]=7f1d0071e91700f9e83c0054 [1328]=7f1d0071e91700f9e7010014
        [429]=....0034f3031f2af4031f2a....0014 [1429]=1f2003d5f3031f2af4031f2a47000014
        [531]=10b1002500244ce0 [1531]=00bf0025002456e0
        [530]=18b100244ff0000b4d [1530]=002000244ff0000b57
        [529]=44387810b1002400254a [1529]=44387800200024002556
        [629]=90387810b1002400254a [1629]=90387800200024002558
    )

    local HEXDATA
    HEXDATA="$(xxd -p -c 0 "$BT_LIB_FILE")" || return 1

    local PATCHED=0

    for idx in "${!hex[@]}"; do
        (( idx >= 1000 )) && continue

        local from="${hex[$idx]}"
        local to="${hex[$((idx + 1000))]}"

        [ -z "$to" ] && continue

        # convert wildcard .... → regex
        local from_regex="${from//./[0-9a-f]}"

        if echo "$HEXDATA" | grep -qiE "$from_regex"; then
            echo "- Found Bluetooth patch pattern [$idx]"
            HEX_PATCH "$BT_LIB_FILE" "$from" "$to" || return 1
            PATCHED=1
			cp -rfa "$WORK_DIR/libbluetooth_jni.so" "$EXTRACTED_FIRM_DIR/system/system/lib64/"
            break
        fi
    done

    if [ "$PATCHED" -eq 0 ]; then
        echo "${RED}- No known Bluetooth patch pattern matched.${RESET}"
		rm -rf "$BT_LIB_FILE"
        return 1
    fi

    return 0
}


FIX_VNDK() {
    echo "${YELLOW}- Checking ${RESET}$STOCK_DEVICE ${YELLOW}and${RESET} $TARGET_DEVICE ${YELLOW}vndk version.${RESET}"
    if [ -f "$TARGET_ROM_SYSTEM_EXT_DIR/apex/com.android.vndk.v${STOCK_VNDK_VERSION}.apex" ]; then
        echo "${GREEN}- VNDK matched.${RESET}"
    else
        echo "${RED}- VNDK mismatch or missing.${RESET}"
        echo "${YELLOW}- Extracting VNDK from $STOCK_DEVICE${RESET}"
        rm -f "$TARGET_ROM_SYSTEM_EXT_DIR/apex/com.android.vndk"*.apex
        mkdir -p "$TARGET_ROM_SYSTEM_EXT_DIR/apex/"
        cp -rfa "$VNDKS_COLLECTION/vndk31-a16/com.android.vndk.v${STOCK_VNDK_VERSION}.apex" "$TARGET_ROM_SYSTEM_EXT_DIR/apex/"
        sed -i "/<vendor-ndk>/,/<\/vendor-ndk>/ s|<version>[0-9]\+</version>|<version>${STOCK_VNDK_VERSION}</version>|" "$TARGET_ROM_SYSTEM_EXT_DIR/etc/vintf/manifest.xml"
    fi
}


FIX_SYSTEM_EXT() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

	if [[ ! -d "$EXTRACTED_FIRM_DIR/system_ext" ]]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system/system_ext"
	fi

    # Make system_ext merged with system
    if [[ "$STOCK_HAS_SEPARATE_SYSTEM_EXT" == FALSE && -d "$EXTRACTED_FIRM_DIR/system_ext" ]]; then
	    echo "${YELLOW}Fixing system_ext according to ${RESET}$STOCK_DEVICE"
        echo "${YELLOW}Copying system_ext content into system root${RESET}"
		rm -rf "$EXTRACTED_FIRM_DIR/system/system_ext"
        cp -a --preserve=all "$EXTRACTED_FIRM_DIR/system_ext" "$EXTRACTED_FIRM_DIR/system"

        echo "${YELLOW}Cleaning and merging system_ext file contexts and configs${RESET}"
        # File paths
        SYSTEM_EXT_CONFIG_FILE="$EXTRACTED_FIRM_DIR/config/system_ext_fs_config"
        SYSTEM_EXT_CONTEXTS_FILE="$EXTRACTED_FIRM_DIR/config/system_ext_file_contexts"

        SYSTEM_CONFIG_FILE="$EXTRACTED_FIRM_DIR/config/system_fs_config"
        SYSTEM_CONTEXTS_FILE="$EXTRACTED_FIRM_DIR/config/system_file_contexts"

        SYSTEM_EXT_TEMP_CONFIG="${SYSTEM_EXT_CONFIG_FILE}.tmp"
        SYSTEM_EXT_TEMP_CONTEXTS="${SYSTEM_EXT_CONTEXTS_FILE}.tmp"

        # Clean system_ext contexts
        grep -v '^/ u:object_r:system_file:s0$' "$SYSTEM_EXT_CONTEXTS_FILE" \
        | grep -v '^/system_ext u:object_r:system_file:s0$' \
        | grep -v '^/system_ext(.*)? u:object_r:system_file:s0$' \
        | grep -v '^/system_ext/ u:object_r:system_file:s0$' \
        > "$SYSTEM_EXT_TEMP_CONTEXTS" && mv "$SYSTEM_EXT_TEMP_CONTEXTS" "$SYSTEM_EXT_CONTEXTS_FILE"

        # Clean system_ext config
        grep -v '^/ 0 0 0755$' "$SYSTEM_EXT_CONFIG_FILE" \
        | grep -v '^system_ext/ 0 0 0755$' \
        | grep -v '^system_ext/lost+found 0 0 0755$' \
        > "$SYSTEM_EXT_TEMP_CONFIG" && mv "$SYSTEM_EXT_TEMP_CONFIG" "$SYSTEM_EXT_CONFIG_FILE"

        # Fix system_ext config
        awk '{print "system/" $0}' "$SYSTEM_EXT_CONFIG_FILE" \
        > "$SYSTEM_EXT_TEMP_CONFIG" && mv "$SYSTEM_EXT_TEMP_CONFIG" "$SYSTEM_EXT_CONFIG_FILE"

        # Fix system_ext contexts
        awk '{print "/system" $0}' "$SYSTEM_EXT_CONTEXTS_FILE" \
        > "$SYSTEM_EXT_TEMP_CONTEXTS" && mv "$SYSTEM_EXT_TEMP_CONTEXTS" "$SYSTEM_EXT_CONTEXTS_FILE"

        # Append cleaned system_ext config into system config
        cat "$SYSTEM_EXT_CONFIG_FILE" >> "$SYSTEM_CONFIG_FILE"

        # Append cleaned system_ext contexts into system contexts
        cat "$SYSTEM_EXT_CONTEXTS_FILE" >> "$SYSTEM_CONTEXTS_FILE"

		export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"

	    rm -rf "$EXTRACTED_FIRM_DIR/system_ext"
		rm -rf "$EXTRACTED_FIRM_DIR/config/system_ext_fs_config"
		rm -rf "$EXTRACTED_FIRM_DIR/config/system_ext_file_contexts"
    fi
}


AUTO_FIX_SELINUX() {
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> [TARGET_VER]"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="${1%/}"
    local TARGET_VER="${2:-${SELINUX_TARGET_VER:-${STOCK_VNDK_VERSION:-31}}}"

    echo "${YELLOW}--- AUTO_FIX_SELINUX (target v${TARGET_VER}) ---${RESET}"

    # secilc in the host PATH?
    if command -v secilc &>/dev/null; then
        local SECILC_RUNNER="secilc"
    else
        echo "${YELLOW}  [!] secilc not available. Skipping AUTO_FIX_SELINUX.${RESET}"
        return 0
    fi

    local SYSTEM_EXT_DIR
    if [ -d "$EXTRACTED_FIRM_DIR/system/system_ext/etc/selinux" ]; then
        SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"
    elif [ -d "$EXTRACTED_FIRM_DIR/system/system/system_ext/etc/selinux" ]; then
        SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system/system_ext"
    else
        SYSTEM_EXT_DIR="${TARGET_ROM_SYSTEM_EXT_DIR:-$EXTRACTED_FIRM_DIR/system/system/system_ext}"
    fi
    local CIL_SET=(
        "$EXTRACTED_FIRM_DIR/system/system/etc/selinux/plat_sepolicy.cil"
        "$EXTRACTED_FIRM_DIR/system/system/etc/selinux/mapping/${TARGET_VER}.0.cil"
        "$SYSTEM_EXT_DIR/etc/selinux/mapping/${TARGET_VER}.0.compat.cil"
        "$SYSTEM_EXT_DIR/etc/selinux/system_ext_sepolicy.cil"
        "$SYSTEM_EXT_DIR/etc/selinux/mapping/${TARGET_VER}.0.cil"
        "$SYSTEM_EXT_DIR/etc/selinux/mapping/${TARGET_VER}.0.compat.cil"
        "$EXTRACTED_FIRM_DIR/product/etc/selinux/product_sepolicy.cil"
        "$EXTRACTED_FIRM_DIR/product/etc/selinux/mapping/${TARGET_VER}.0.cil"
        "$EXTRACTED_FIRM_DIR/vendor/etc/selinux/plat_pub_versioned.cil"
        "$EXTRACTED_FIRM_DIR/vendor/etc/selinux/vendor_sepolicy.cil"
    )

    # If any required CIL is missing, warn and skip (build continues)
    local MISSING_CIL=()
    for c in "${CIL_SET[@]}"; do
        [ ! -f "$c" ] && MISSING_CIL+=("${c#$EXTRACTED_FIRM_DIR/}")
    done
    if [ "${#MISSING_CIL[@]}" -gt 0 ]; then
        echo "${YELLOW}  [!] Required CILs missing, skipping AUTO_FIX_SELINUX:${RESET}"
        printf '      - %s\n' "${MISSING_CIL[@]}"
        return 0
    fi

    local OUTPUT_TMP
    OUTPUT_TMP=$(mktemp)
    local MAX_ITER=500
    local iteration=0 total=0

    while [ "$iteration" -lt "$MAX_ITER" ]; do
        iteration=$((iteration + 1))

        local secilc_exit=0
        local secilc_output
        secilc_output=$("$SECILC_RUNNER" -m -M true -G -N -v -c "$TARGET_VER" \
            "${CIL_SET[@]}" -o "$OUTPUT_TMP" -f /dev/null 2>&1) || secilc_exit=$?

        # Only consider the compile successful when secilc really exits 0. Relying on
        # a text match alone can mask errors like "Found conflicting genfscon rules"
        # that don't contain "Failed to resolve".
        if [ "$secilc_exit" -eq 0 ]; then
            echo "${GREEN}  [+] Policy compiled successfully (iteration $iteration).${RESET}"
            break
        fi

        local fixed=0
        while IFS= read -r err_line; do
            [ -z "$err_line" ] && continue

            local loc
            loc=$(echo "$err_line" | grep -oP 'at\s+\K\S+:\d+' | head -1 || true)
            [ -z "$loc" ] && continue

            local file="${loc%%:*}"
            local line_num="${loc##*:}"
            [ ! -f "$file" ] && continue

            # Skip if it is already a comment (idempotent)
            if sed -n "${line_num}p" "$file" | grep -qP '^\s*;;'; then
                continue
            fi

            sed -i "${line_num}s/^\(\s*\)/\1;; [auto-fixed] /" "$file"
            echo "  ${RED}[x] Commented:${RESET} ${file#$EXTRACTED_FIRM_DIR/}:$line_num"
            fixed=$((fixed + 1))
            total=$((total + 1))
        done <<< "$secilc_output"

        if [ "$fixed" -eq 0 ]; then
            echo "${YELLOW}  [!] Could not fix any more errors.${RESET}"
            echo "$secilc_output" | head -15
            break
        fi
    done

    rm -f "$OUTPUT_TMP"
    echo "${GREEN}  [+] AUTO_FIX_SELINUX: $total lines commented in $iteration iterations.${RESET}"
}


REMOVE_LINE() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <TARGET_LINE> <TARGET_FILE>"
        return 1
    fi

    local LINE="$1"
    local FILE="$2"

    echo "${YELLOW}Deleting${RESET} $LINE ${YELLOW}from${RESET} $FILE"
    grep -vxF "$LINE" "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
}


FIX_PROPERTY_CONTEXTS() {
    local EXTRACTED_FIRM_DIR="${1%/}"

    local WIFIX_WHITELIST=(
        "init.svc.vendor.wvkprov_server_hal"
    )

    local PLAT="$EXTRACTED_FIRM_DIR/system/system/etc/selinux/plat_property_contexts"

    local SYSTEM_EXT_DIR
    if [ -d "$EXTRACTED_FIRM_DIR/system/system_ext/etc/selinux" ]; then
        SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"
    elif [ -d "$EXTRACTED_FIRM_DIR/system/system/system_ext/etc/selinux" ]; then
        SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system/system_ext"
    else
        SYSTEM_EXT_DIR="${TARGET_ROM_SYSTEM_EXT_DIR:-$EXTRACTED_FIRM_DIR/system/system/system_ext}"
    fi
    local SYSTEM_EXT="$SYSTEM_EXT_DIR/etc/selinux/system_ext_property_contexts"

    local PRODUCT="$EXTRACTED_FIRM_DIR/product/etc/selinux/product_property_contexts"
    local VENDOR="$EXTRACTED_FIRM_DIR/vendor/etc/selinux/vendor_property_contexts"

    echo "${YELLOW}Fixing duplicate property-context prefixes${RESET}"

    local FILES=("$PLAT" "$SYSTEM_EXT" "$PRODUCT" "$VENDOR")
    local NAMES=("plat" "system_ext" "product" "vendor")

    # Collect active lines: prefix<TAB>priority<TAB>name<TAB>line_number<TAB>field_count
    local TMP_ALL=$(mktemp)
    local i
    for ((i=0; i<4; i++)); do
        local f="${FILES[$i]}"
        [ -f "$f" ] || continue
        awk -v prio="$((i+1))" -v name="${NAMES[$i]}" \
            '!/^#/ && $1 != "" {print $1 "\t" prio "\t" name "\t" NR "\t" NF}' "$f" >> "$TMP_ALL"
    done

    # Duplicate prefixes = prefixes appearing more than once
    local TMP_DUPES=$(mktemp)
    awk -F'\t' '
        { n=$1; if (!(n in c)) { order[++o]=n } c[n]++ }
        END { for (i=1;i<=o;i++) if (c[order[i]]>1) print order[i] }
    ' "$TMP_ALL" | grep -Fx -e "${WIFIX_WHITELIST[@]}" > "$TMP_DUPES"

    local COUNT
    COUNT=$(wc -l < "$TMP_DUPES" | tr -d ' ')
    if [ "$COUNT" -eq 0 ]; then
        echo "${GREEN}  [+] No whitelisted duplicate property-context prefixes.${RESET}"
        rm -f "$TMP_ALL" "$TMP_DUPES"
        return 0
    fi

    echo "  [!] $COUNT whitelisted duplicate prefix(es):"
    sed 's/^/    - /' "$TMP_DUPES"

    local removed=0
    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue

        # File to keep = the one with the highest priority
        local keep_name
        keep_name=$(awk -F'\t' -v p="$prefix" '$1==p {print $3 "\t" $2}' "$TMP_ALL" | sort -k2,2nr | head -1 | cut -f1)
        [ -z "$keep_name" ] && continue

        for ((i=0; i<4; i++)); do
            local f="${FILES[$i]}"
            [ -f "$f" ] || continue
            local name="${NAMES[$i]}"

            if [ "$name" == "$keep_name" ]; then
                # In the kept file keep only the most specific (max field count) entry
                local best
                best=$(awk -F'\t' -v p="$prefix" -v n="$name" '$1==p && $3==n {print $5 "\t" $4}' "$TMP_ALL" | sort -k1,1nr -k2,2n | head -1 | cut -f2)
                local TMP_OUT=$(mktemp)
                awk -v p="$prefix" -v b="$best" '!/^#/ && $1==p && NR!=b {next} {print}' "$f" > "$TMP_OUT"
                cp "$TMP_OUT" "$f" 2>/dev/null || echo "    [!] could not rewrite $name (permission)"
                rm -f "$TMP_OUT"
            else
                # Remove the prefix entirely from lower-priority files
                if awk -v p="$prefix" '!/^#/ && $1==p {found=1; exit} END {exit !found}' "$f"; then
                    local TMP_OUT2=$(mktemp)
                    awk -v p="$prefix" '!/^#/ && $1==p {next} {print}' "$f" > "$TMP_OUT2"
                    cp "$TMP_OUT2" "$f" 2>/dev/null || echo "    [!] could not rewrite $name (permission)"
                    rm -f "$TMP_OUT2"
                    echo "    - removed '$prefix' from $name (kept in $keep_name)"
                    removed=$((removed + 1))
                fi
            fi
        done
    done < "$TMP_DUPES"

    rm -f "$TMP_ALL" "$TMP_DUPES"
    echo "${GREEN}  [+] $removed duplicate property-context lines removed.${RESET}"
}


UPDATE_FLOATING_FEATURE() {
    local key="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo "${RED}[Omitted]${RESET} $key ${RED}— no value found.${RESET}"
        return
    fi

    if grep -q "<${key}>.*</${key}>" "$TARGET_FLOATING_FEATURE"; then
        local current_line
        current_line=$(grep "<${key}>.*</${key}>" "$TARGET_FLOATING_FEATURE")
        local current_value
        current_value=$(echo "$current_line" | sed -E "s/.*<${key}>(.*)<\/${key}>.*/\1/")

        if [[ "$current_value" == "$value" ]]; then
            return
        fi

        local indent
        indent=$(echo "$current_line" | sed -E "s/(<${key}>.*<\/${key}>).*//")
        local line="${indent}<${key}>${value}</${key}>"
        sed -i "s|${indent}<${key}>.*</${key}>|$line|" "$TARGET_FLOATING_FEATURE"
        echo "${GREEN}Updated ${RESET}$key${GREEN} with => ${RESET}$value"
    else
        local line="    <$key>$value</$key>"
        sed -i "3i\\$line" "$TARGET_FLOATING_FEATURE"
        echo "${GREEN}Added ${RESET}$key${GREEN} with value => ${RESET}$value"
    fi
}


APPLY_FLOATING_FEATURE() {
    echo ""
	echo "${BLUE}============ Floating Feature ============${RESET}"
    #========== COMMON ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_CONFIG_SEP_CATEGORY" "sep_basic"

    #========== EDGE ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_CONFIG_EDGE" "panel"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SYSTEMUI_CONFIG_EDGELIGHTING_FRAME_EFFECT" "frame_effect"

    #========== SCREEN RECORDER ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_SCREEN_RECORDER" "TRUE"
	
	#========== VOICE RECORDER ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_VOICERECORDER_CONFIG_DEF_MODE" "normal,interview,voicememo"

    #========== AUDIO ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_BT_RECORDING" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_STAGE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_STAGE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_VOLUME_MONITOR" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_VOLUME_MONITOR" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_REMOTE_MIC" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_AUDIO_CONFIG_REMOTE_MIC" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_SOUNDALIVE_VERSION" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_AUDIO_CONFIG_SOUNDALIVE_VERSION" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_GAIN" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_GAIN" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== SETTINGS ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_DEFAULT_DOUBLE_TAP_TO_WAKE" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_FUNCTION_KEY_MENU" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_ELECTRIC_RATED_VALUE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_ELECTRIC_RATED_VALUE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_BRAND_NAME" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_BRAND_NAME" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_DEFAULT_FONT_SIZE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_DEFAULT_FONT_SIZE" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== REFRESH RATE ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_MODE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_MODE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== SYSTEM ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SYSTEM_SUPPORT_ENHANCED_CPU_RESPONSIVENESS" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SYSTEM_SUPPORT_ENHANCED_PROCESSING" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== LAUNCHER ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LAUNCHER_SUPPORT_CLOCK_LIVE_ICON" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LAUNCHER_CONFIG_ANIMATION_TYPE" "HighEnd"

    #========== DISPLAY ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_DEFAULT_SCREEN_MODE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_CONFIG_DEFAULT_SCREEN_MODE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_SUPPORT_NATURAL_SCREEN_MODE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_SUPPORT_NATURAL_SCREEN_MODE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_SUPPORT_SCREEN_MODE_TYPE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_SUPPORT_SCREEN_MODE_TYPE" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== CAMERA ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_STRIDE_OCR_VERSION" "V1"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_SUPPORT_PRIVACY_TOGGLE" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_BINNING" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_BINNING" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_MEMORY_USAGE_LEVEL" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_MEMORY_USAGE_LEVEL" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_QRCODE_INTERVAL" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_QRCODE_INTERVAL" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_UW_DISTORTION_CORRECTION" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_UW_DISTORTION_CORRECTION" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_AVATAR_MAX_FACE_NUM" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_AVATAR_MAX_FACE_NUM" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_STANDARD_CROP" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_STANDARD_CROP" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_HIGH_RESOLUTION_MAX_CAPTURE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_HIGH_RESOLUTION_MAX_CAPTURE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_NIGHT_FRONT_DISPLAY_FLASH_TRANSPARENT" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_NIGHT_FRONT_DISPLAY_FLASH_TRANSPARENT" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== BIOAUTH ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_BIOAUTH_CONFIG_FINGERPRINT_FEATURES" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_BIOAUTH_CONFIG_FINGERPRINT_FEATURES" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== LOCKSCREEN ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LOCKSCREEN_CONFIG_PUNCHHOLE_VI" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LOCKSCREEN_CONFIG_PUNCHHOLE_VI" {print $3}' "$STOCK_FLOATING_FEATURE")"

	#========== MANUFACTUREER TYPE ==========#
	UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_CONFIG_DEVICE_MANUFACTURING_TYPE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_COMMON_CONFIG_DEVICE_MANUFACTURING_TYPE" {print $3}' "$STOCK_FLOATING_FEATURE")"

}


REMOVE_ESIM_FILES() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    # Remove ESIM files as we dont need it
	local EXTRACTED_FIRM_DIR="$1"
    echo "${YELLOW}- Removing ESIM files.${RESET}"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EsimClient"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EsimKeyString"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EuiccService"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.euicc.xml"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.euicc.xml"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.esimkeystring.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.android.app.esimkeystring.xml"
}


REMOVE_FABRIC_CRYPTO() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    # Yes, we dont need that, it spams logs
	local EXTRACTED_FIRM_DIR="$1"
    echo "${YELLOW}- Removing fabric crypto.${RESET}"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/bin/fabric_crypto"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/fabric_crypto.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/FabricCryptoLib.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/vintf/manifest/fabric_crypto_manifest.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/FabricCryptoLib.jar"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm/FabricCryptoLib.odex"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm/FabricCryptoLib.vdex"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm64/FabricCryptoLib.odex"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm64/FabricCryptoLib.vdex"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/com.samsung.security.fabric.cryptod-V1-cpp.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-ndk.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/KmxService"
}

JDM_DEBLOAT() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    # I added JDM Debloat separately from Debloat to have better control over it 
    local EXTRACTED_FIRM_DIR="$1"
    local STOCK_FLOATING_FEATURE="$DEVICES_DIR/$STOCK_DEVICE/floating_feature.xml"
    local MANUF_TYPE
    MANUF_TYPE=$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_COMMON_CONFIG_DEVICE_MANUFACTURING_TYPE" {print $3}' "$STOCK_FLOATING_FEATURE" | xargs)

    shopt -s nocasematch

    if [[ "$MANUF_TYPE" == *jdm* ]]; then
        echo "${GREEN}JDM detected → debloating unnecessary files${RESET}"
        rm -rf -- "$EXTRACTED_FIRM_DIR/system/system/app/BluetoothAgent"
        rm -rf -- "$EXTRACTED_FIRM_DIR/system/system/app/BluetoothMidiService"
        rm -rf -- "$EXTRACTED_FIRM_DIR/system/system/priv-app/SamsungCamera"
    else
        echo "${RED}[Omitted] Device is not JDM → skipping JDM debloating${RESET}"
    fi

    shopt -u nocasematch
}

APPLY_STOCK_CONFIG() {
    echo ""
	echo "${GREEN}Applying ${RESET}$STOCK_DEVICE ${GREEN}device config.${RESET}"
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    if [ ! -f "$DEVICES_DIR/$STOCK_DEVICE/config" ]; then
        echo "${RED}[Omitted] Config file for $STOCK_DEVICE not found in $DEVICES_DIR${RESET}"
        return 1
	fi

    if [ -f "$DEVICES_DIR/$STOCK_DEVICE/config" ]; then
        echo "${GREEN}-${RESET} $STOCK_DEVICE ${GREEN}config found.${RESET}"
        export STOCK_VNDK_VERSION="$(grep -m1 '^STOCK_VNDK_VERSION=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
        export STOCK_HAS_SEPARATE_SYSTEM_EXT="$(grep -m1 '^STOCK_HAS_SEPARATE_SYSTEM_EXT=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
		export STOCK_DVFS_FILENAME="$(grep -m1 '^STOCK_DVFS_FILENAME=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
    fi

    export STOCK_FLOATING_FEATURE="$DEVICES_DIR/$STOCK_DEVICE/floating_feature.xml"
	export TARGET_FLOATING_FEATURE="$EXTRACTED_FIRM_DIR/system/system/etc/floating_feature.xml"
	export STOCK_SIOP_FILENAME="$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" {print $3}' "$STOCK_FLOATING_FEATURE" | tr -d '\r' | xargs)"

	# FIX SYSTEM_EXT.
    FIX_SYSTEM_EXT "$EXTRACTED_FIRM_DIR"

	# FIX VNDK.
	FIX_VNDK

    # Floating Feature.
    APPLY_FLOATING_FEATURE

    # Fix unsupported BPF error for kernels lower than 5.10.
    if [ "$USE_UI_8_TETHERING_APEX" = "true" ]; then
        cp -rfa "$(pwd)/LumiROM/Mods/bpf_patch/." "$EXTRACTED_FIRM_DIR/"
    fi

	# Replace Stock Files.
	rm -rf $EXTRACTED_FIRM_DIR/product/overlay/framework-res*auto_generated_rro_product.apk
    cp -af "$DEVICES_DIR/$STOCK_DEVICE/Stock/." "$EXTRACTED_FIRM_DIR/"

    # Fix duplicate property-context prefixes (prevents init fatal bootloop).
    FIX_PROPERTY_CONTEXTS "$EXTRACTED_FIRM_DIR"

}


DEBLOAT_APPS=("FactoryCameraFB" "HybridRadio" "CIDManager" "SBrowser" "Facebook_stub_TFN" "FBAppManager_TFN" "SamsungTTSVoice_es_US_l01 " "SamsungCalendar" "KTAuth_Stub" "GameTools_Dream" "Gmail2" "Maps" "Duo" "Velvet" "CarrierDefaultApp" "ccinfo" "Chrome" "ChromeCustomizations" "GameHome" "GameOptimizingService" "WlanTest" "AssistantShell" "HotwordEnrollmentOKGoogleEx4CORTEXM55" "HotwordEnrollmentXGoogleEx4CORTEXM55" "BardShell" "DuoStub" "GoogleCalendarSyncAdapter" "AndroidDeveloperVerifier" "AndroidGlassesCore" "SOAgent77" "YourPhone_Stub" "AndroidAutoStub" "SingleTakeService" "SamsungBilling" "AndroidSystemIntelligence" "GoogleRestore" "SamsungMessages" "SamsungPositioning" "YouTube"  "SearchSelector" "AirGlance" "AirReadingGlass" "SamsungTTS" "WlanTest" "ARCore" "ARDrawing" "ARZone" "BGMProvider" "BixbyWakeup" "BlockchainBasicKit" "Cameralyzer" "DictDiotekForSec" "EasymodeContactsWidget81" "Fast" "FBAppManager_NS" "FunModeSDK" "GearManagerStub" "KidsHome_Installer" "LinkSharing_v11" "LiveDrawing" "MAPSAgent" "MdecService" "MoccaMobile" "Netflix_stub" "Notes40" "ParentalCare" "PhotoTable" "PlayAutoInstallConfig" "SamsungPassAutofill_v1" "SamsungTTSVoice_de_DE_f00" "SamsungTTSVoice_el_GR_f00" "SamsungTTSVoice_en_GB_f00" "SamsungTTSVoice_en_US_f00" "SamsungTTSVoice_en_US_l03" "SamsungTTSVoice_es_ES_f00" "SamsungTTSVoice_es_MX_f00" "SamsungTTSVoice_es_US_f00" "SamsungTTSVoice_fr_FR_f00" "SamsungTTSVoice_hi_IN_f00" "SamsungTTSVoice_it_IT_f00" "SamsungTTSVoice_pl_PL_f00" "SamsungTTSVoice_pt_BR_f00" "SamsungTTSVoice_ru_RU_f00" "SamsungTTSVoice_th_TH_f00" "SamsungTTSVoice_vi_VN_f00" "SamsungTTSVoice_en_IN_f00" "SmartReminder" "SmartSwitchStub" "UnifiedWFC" "UniversalMDMClient" "VideoEditorLite_Dream_N" "VisionIntelligence3.7" "VoiceAccess" "VTCameraSetting" "WebManual" "WifiGuider" "KTAuth" "KTCustomerService" "KTUsimManager" "LGUMiniCustomerCenter" "LGUplusTsmProxy" "SamsungTTSVoice_ko_KR_r00" "SketchBook" "SKTMemberShip_new" "SktUsimService" "TWorld" "AirCommand" "AppUpdateCenter" "AREmoji" "AREmojiEditor" "AuthFramework" "AutoDoodle" "AvatarEmojiSticker" "AvatarEmojiSticker_S" "Bixby" "BixbyInterpreter" "BixbyVisionFramework3.5" "DevGPUDriver-EX2200" "DigitalKey" "Discover" "DiscoverSEP" "EarphoneTypeC" "EasySetup" "FBInstaller_NS" "FBServices" "FotaAgent" "GalleryWidget" "GameDriver-EX2100" "GameDriver-EX2200" "GameDriver-SM8150" "HashTagService" "MultiControlVP6" "LedCoverService" "LinkToWindowsService" "LiveStickers" "MemorySaver_O_Refresh" "MultiControl" "OMCAgent5" "OneDrive_Samsung_v3" "OneStoreService" "SamsungCarKeyFw" "SamsungPass" "SettingsBixby" "SetupIndiaServicesTnC" "SKTFindLostPhone" "SKTHiddenMenu" "SKTMemberShip" "SKTOneStore" "SktUsimService" "SmartEye" "SmartPush" "SmartThingsKit" "SmartTouchCall" "SOAgent7" "SOAgent75" "SolarAudio-service" "SPPPushClient" "sticker" "StickerFaceARAvatar" "StoryService" "SumeNNService" "SVoiceIME" "SwiftkeyIme" "SwiftkeySetting" "SystemUpdate" "TADownloader" "TalkbackSE" "TaPackAuthFw" "TPhoneOnePackage" "TPhoneSetup" "TWorld" "UltraDataSaving_O" "Upday" "UsimRegistrationKOR" "YourPhone_P1_5" "AvatarPicker" "KT114Provider2" "KTHiddenMenu" "KTOneStore" "KTServiceAgent" "KTServiceMenu" "LGUGPSnWPS" "LGUHiddenMenu" "LGUOZStore" "SKTFindLostPhoneApp" "SmartPush_64" "SOAgent76" "TService" "vexfwk_service" "VexScanner" "LiveEffectService" "YourPhone_P1_5" "vexfwk_service" "AutoHotspotMDE")

KICK() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    
	local EXTRACTED_FIRM_DIR="$1"

    echo "${YELLOW}- Debloating apps.${RESET}"
    local APP_DIRS=(
        "$EXTRACTED_FIRM_DIR/system/system/app"
        "$EXTRACTED_FIRM_DIR/system/system/priv-app"
        "$EXTRACTED_FIRM_DIR/product/app"
        "$EXTRACTED_FIRM_DIR/product/priv-app"
    )

    for app in "${DEBLOAT_APPS[@]}"; do
        for dir in "${APP_DIRS[@]}"; do
            target="$dir/$app"

            if [[ -d "$target" ]]; then
                rm -rf "$target" || echo "[WARN] Failed to remove $target"
            fi
        done
    done
}


DEBLOAT() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"

    KICK "$EXTRACTED_FIRM_DIR"
    REMOVE_ESIM_FILES "$EXTRACTED_FIRM_DIR"
	REMOVE_FABRIC_CRYPTO "$EXTRACTED_FIRM_DIR"
    JDM_DEBLOAT "$EXTRACTED_FIRM_DIR"
    DEODEX "$EXTRACTED_FIRM_DIR"
    
	echo "${YELLOW}- Deleting unnecessary files and folders.${RESET}"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/boot-image.bprof"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/boot-image.prof"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/hidden"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/preload"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/tts"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/mediasearch"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/MediaSearch"


    if [[ "$STOCK_DEVICE" == "SM-A225F" ]]; then
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/libnfc-sec.so"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/libnfc_sec_jni.so"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib/libnfc_sec_jni.so"
        echo "${GREEN}Removed NFC from stock image${RESET}"
    fi
    
}

DEODEX() {
    echo "${YELLOW}- Deodexing ROM (removing oat folders)...${RESET}"
    echo "${YELLOW}- OAT folders to remove:${RESET}"

    local SEARCH_DIRS=(
        "$EXTRACTED_FIRM_DIR/system/system_ext/priv-app"
        "$EXTRACTED_FIRM_DIR/system/system_ext/app"
        "$EXTRACTED_FIRM_DIR/system/system/priv-app"
        "$EXTRACTED_FIRM_DIR/system/system/app"
    )

    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -type d -name "oat" | sed "s|$EXTRACTED_FIRM_DIR/|    - |"
            sudo find "$dir" -type d -name "oat" -exec rm -rf {} +
        else
            echo "${RED}[Omitted]${RESET} $dir ${RED}not found, skipping.${RESET}"
        fi
    done

    echo "${GREEN}Deodex complete${RESET}"
}

BUILD_PROP() {
    local EXTRACTED_FIRM_DIR="$1"
    local KEY="$2"
    local VALUE="${3:-}"

    if [ -z "$EXTRACTED_FIRM_DIR" ] || [ -z "$KEY" ]; then
        echo "Usage: BUILD_PROP <EXTRACTED_FIRM_DIR> <key> [value]"
        return 1
    fi

    local PROP_FILES=(
        "$EXTRACTED_FIRM_DIR/system/system/build.prop"
    )
    for PROP in "${PROP_FILES[@]}"; do
        [ -f "$PROP" ] || continue

        if [ -z "$VALUE" ]; then
            sudo sed -i "/^${KEY}=.*/d" "$PROP"
            echo "${RED}Removed ${RESET}$KEY"
        else
            if sudo grep -q "^${KEY}=" "$PROP"; then
                sudo sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$PROP"
                echo "${GREEN}Updated ${RESET}$KEY${GREEN} with value => ${RESET}$VALUE${RESET}"
            else
                echo "${KEY}=${VALUE}" | sudo tee -a "$PROP" > /dev/null
                echo "${GREEN}Added ${RESET}$KEY${GREEN} with value => ${RESET}$VALUE${RESET}"
            fi
        fi
    done
}


APPLY_PROP_FEATURES() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"

    # Add build.prop features
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.product.locale" "en-US"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "wifi.interface" "wlan0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "wlan.wfd.hdcp" "disabled"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.hwui.renderer" "opengl"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.hwui.skia_atrace_enabled" "false"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.renderengine.backend" "skiaglthreaded"
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.telephony.sim_slots.count" "2"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.surface_flinger.protected_contents" "false"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.audio.voip.enabled" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.vendor.audio.voip" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.audio.recording.voip" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.atrace.app_%d" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.atrace.app_number" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.atrace.prefer_sdk" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.atrace.tags.enableflags" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.atrace.user_initiated" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.documentscan.loglevel" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.documentscan.timelog" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.egl.trace" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.egl.traceGpuCompletion" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.hdr.log.hdr10plus" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.hwui.skia_tracing_enabled" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.hwui.trace_gpu_resources" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.incremental.enforce_readlogs_max_interval_for_system_dataloaders" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.incremental.readlogs_max_interval_sec" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.log" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.printbacktraceselfkill" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.tflite.trace" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.thirdpartylogs.enabled" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.tracing" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.tracing.ctl.hwui.skia_tracing_enabled" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.tracing.ctl.hwui.skia_use_perfetto_track_events" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.tracing.ctl.perfetto.sdk_sysprop_guard_generation" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.tracing.ctl.renderengine.skia_tracing_enabled" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.tracing.ctl.renderengine.skia_use_perfetto_track_events" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.tracing.screen_brightness" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.tracing.screen_state" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.unihal.logStatus" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.vulkan.profiler.apitrace" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.config.iccc_version" "Disabled"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "dalvik.vm.systemuicompilerfilter" "speed"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.adb.notify" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.surface_flinger.max_frame_buffer_acquired_buffers" "4"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.hwui.use_triple_buffering" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.sf.enable_gl_backpressure" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.critical_upgrade" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.swap_compression_ratio" "3"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.filecache_min_kb" "200600"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.swap_util_max" "85"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.psi_complete_stall_ms" "200"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.psi_partial_stall_ms" "200"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.swap_free_low_percentage" "10"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.stall_limit_critical" "40"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.thrashing_limit" "30"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.thrashing_limit_decay" "50"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lmk.use_psi" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.2nd.dha_cached_max" "12"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.2nd.dha_empty_max" "24"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.2nd.freelimit_val" "10"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.2nd.swap_free_low_percentage" "10"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.2nd.upgrade_pressure" "1000"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.allied_proc_protect" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.base_swaptotal" "4096"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.beks_enable" "false"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.beks_key" "166"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.c_deadline_zone_on_off" "false"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.cam_kill_start_minutes" "30"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.chimera.protect_activitytime_ms" "600000"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.chimera_strategy_4gb" "0,0,0,0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.chimera_strategy_6gb" "0,0,0,0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.chimera.quickreclaim_enable" "false"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.chimera.quickreclaim_big_game_enable" "false"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.chimera_quota_enable" "false"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dec_EFK_enable" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_2ndprop_thMB" "4096"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_cached_min" "4"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_cached_max" "16"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_dialer_except_th" "2048"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_empty_init" "12"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_empty_min" "8"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_empty_max" "24"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_lmk_array" "8940,11649,14359,18017,27768,38398"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_lmk_scale" "0.3"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_pwhl_key" "0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.dha_th_rate" "3.5"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.enable_reentry_lmk" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.enable_upgrade_criadj" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.enable_userspace_lmk" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.fha_enable" "false"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.freelimit_val" "10"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.kill_heaviest_task" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.max_snapshot_num" "3"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.plg_key" "4"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.psi_critical" "160"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.swap_free_low_percentage" "10"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.trim_sec_policy" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.upgrade_pressure" "1000"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.use_bg_keeping_policy" "false"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.use_bg_keeping_policy_light" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.use_camera_boost" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.slmk.use_lowmem_keep_except" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "audio.safemedia.bypass" "true"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.vendor.camera.expose.aux" "1"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "vendor.camera.aux.packagelist" "com.sec.android.app.camera,com.samsung.android.scan3d"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "vendor.camera.aux.packagelist2" "com.simplemobiletools.camera,net.sourceforge.opencamera,com.google.android.googlequicksearchbox,com.google.android.apps.translate,com.google.ar.lens,com.google.android.apps.bard"
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "fw.show_multiuserui" "1"
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "fw.max_users" "5"
    

    # Related to Updater App
    if [ "$USE_MODS" = "true" ]; then
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.cloudy.rom.ver" "$LUMIROM_VERSION"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.cloudy.rom.ver.code" "$LUMIROM_CODE"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.cloudy.maintainer" "$LUMIROM_MAINTAINER"
    fi

    # The vendor build.prop overrides the system one at boot, so patch it here
    # to ensure the threaded Skia renderengine backend is actually used.
    local VENDOR_BUILD_PROP="$EXTRACTED_FIRM_DIR/vendor/build.prop"
    if [ -f "$VENDOR_BUILD_PROP" ]; then
        sudo sed -i 's|^debug.renderengine.backend=.*|debug.renderengine.backend=skiaglthreaded|' "$VENDOR_BUILD_PROP"
        echo "${GREEN}Patched ${RESET}vendor/build.prop debug.renderengine.backend => skiaglthreaded${RESET}"
    fi
}

APPEND_DISPLAY_ID() {
    local EXTRACTED_FIRM_DIR="$1"
    local SUFFIX="$2"

    if [ -z "$EXTRACTED_FIRM_DIR" ] || [ -z "$SUFFIX" ]; then
        echo "Usage: APPEND_DISPLAY_ID <EXTRACTED_FIRM_DIR> <text_to_append>"
        return 1
    fi

    local PROP_FILES=(
        "$EXTRACTED_FIRM_DIR/product/etc/build.prop"
        "$EXTRACTED_FIRM_DIR/system/system/build.prop"
    )

    for PROP in "${PROP_FILES[@]}"; do
        [ -f "$PROP" ] || continue

        if grep -q "^ro.build.display.id=" "$PROP"; then
            local CURRENT
            CURRENT=$(grep "^ro.build.display.id=" "$PROP" | cut -d= -f2-)

            # Try to not update it, if it was already there
            if [[ "$CURRENT" != *"$SUFFIX"* ]]; then
                sed -i "s|^ro.build.display.id=.*|ro.build.display.id=${CURRENT} - ${SUFFIX}|" "$PROP"
                echo "${GREEN}Updated ${RESET}ro.build.display.id${GREEN} in ${RESET}$PROP"
            fi
        fi
    done
}

APPENDING_DISPLAY_ID() {
    if [ -z "$1" ]; then
        echo "Usage: APPENDING_DISPLAY_ID <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    # Add a name to build ID, doesnt delete the line, it adds at the end
	local EXTRACTED_FIRM_DIR="$1"

    APPEND_DISPLAY_ID "$1" "LumiROM $LUMIROM_VERSION $BUILD_STATUS Stable"
}


REPLACE_OTACERTS() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    local CERT
    CERT="$(GET_ACTIVE_OTA_CERT)"
    if [ -z "$CERT" ]; then
        echo "${YELLOW}No OTA certificate available, keeping stock otacerts.zip.${RESET}"
        return 0
    fi

    local TMP_DIR
    TMP_DIR="$(mktemp -d)"

    local CERT_NAME
    CERT_NAME="$(printf '%s' "$CERT" | sed "/CERTIFICATE/d" | tr -d "\n" | base64 -d | sha256sum | cut -d ' ' -f 1)"
    CERT_NAME="lumirom_ota_${CERT_NAME:0:16}.x509.pem"

    printf '%s\n' "$CERT" > "$TMP_DIR/$CERT_NAME"

    local OUT_OTACERTS="$EXTRACTED_FIRM_DIR/system/system/etc/security/otacerts.zip"
    mkdir -p "$(dirname "$OUT_OTACERTS")"

    echo "${YELLOW}Building otacerts.zip with LumiROM OTA certificate only...${RESET}"
    rm -f "$OUT_OTACERTS"
    (cd "$TMP_DIR" && zip -q "$OUT_OTACERTS" "$CERT_NAME")

    rm -rf "$TMP_DIR"

    echo "${GREEN}otacerts.zip replaced at $OUT_OTACERTS${RESET}"
    unzip -l "$OUT_OTACERTS"
}
