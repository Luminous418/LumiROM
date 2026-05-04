#!/bin/bash

IS_OFFICIAL() {
    CURRENT_SIGNATURE=$(printf "%s" "$LUMIROM_BUILD" | sha256sum | cut -d ' ' -f 1)

    if [ "$CURRENT_SIGNATURE" == "$OFFICIAL_HASH" ]; then
        export BUILD_STATUS="OFFICIAL"
        export ROM_TAG="✨ LumiROM Official Build"
        
        echo "BUILD_STATUS=OFFICIAL" >> "$GITHUB_ENV"
        echo "ROM_TAG=✨ LumiROM Official Build" >> "$GITHUB_ENV"
    else
        export BUILD_STATUS="UNOFFICIAL"
        export ROM_TAG="🛠️ LumiROM Unofficial Build"
        
        echo "BUILD_STATUS=UNOFFICIAL" >> "$GITHUB_ENV"
        echo "ROM_TAG=🛠️ LumiROM Unofficial Build" >> "$GITHUB_ENV"
    fi

    echo "--- $ROM_TAG detected ---"
}

CHECK_FILE() {
    if [ ! -f "$1" ]; then
        echo "[!] File not found: $1"
        echo "- Skipping..."
        return 1
    fi
    return 0
}


REMOVE_LINE() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <TARGET_LINE> <TARGET_FILE>"
        return 1
    fi

    local LINE="$1"
    local FILE="$2"

    echo "- Deleting $LINE from $FILE"
    grep -vxF "$LINE" "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
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
      echo "Disabling full-based encryption (FBE) for /data..."
      echo "- Found $i."
      # If found file-encryption, comments it
      sudo sed -i -e 's/^\([^#].*\)fileencryption=[^,]*\(.*\)$/# &\n\1encryptable\2/g' $i
      echo "Disabled file-encryption on $i"
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
      echo "Disabling full-disk encryption (FDE) for /data..."
      echo "- Found $i."
      # If found force-encryption, comments it
      sudo sed -i -e 's/^\([^#].*\)forceencrypt=[^,]*\(.*\)$/# &\n\1encryptable\2/g' $i
      echo "Disabled force-encryption on $i"
    fi
  done
}

DELETE_ICCC() {
    local EXTRACTED_FIRM_DIR="$1"
    echo "Starting wipe..."
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
            echo "Deleted $file"
        else
            echo "[Omitted] $file not found"
        fi
    done

    echo "Wipe iccc completed"
}

DEBLOAT_VENDOR() {
    local EXTRACTED_FIRM_DIR="$1"
    echo "Starting Debloat..."

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
            echo "Deleted $file"
        else
            echo "[Omitted] $file not found"
        fi
    done

    echo "Vendor debloat completed"
}

PATCH_FSTAB_EROFS() {
    local EXTRACTED_FIRM_DIR="$1"
    
    if [ -z "$EXTRACTED_FIRM_DIR" ]; then
        echo "Error: FIRM directory not specified."
        return 1
    fi

    echo "Applying patches EROFS to fstab..."

    local fstab_files="
        vendor/etc/fstab.mt6768
        vendor/etc/fstab.mt6769t
        vendor/etc/fstab.mt6833
    "
    # Patch fstab to add EROFS
    for fstab in $fstab_files; do
        local target="$EXTRACTED_FIRM_DIR/$fstab"

        if [ -f "$target" ]; then
            echo "- Processing: $fstab"
            
            # system
            sudo sed -i '/^system \/system ext4/a system\t/system\terofs\tro\twait,,avb=vbmeta_system,logical,first_stage_mount,avb_keys=/avb/q-gsi.avbpubkey:/avb/r-gsi.avbpubkey:/avb/s-gsi.avbpubkey' "$target"
            
            # vendor
            sudo sed -i '/^vendor \/vendor ext4/a vendor\t/vendor\terofs\tro\twait,,avb,logical,first_stage_mount' "$target"
            
            # product
            sudo sed -i '/^product \/product ext4/a product\t/product\terofs\tro\twait,,avb,logical,first_stage_mount' "$target"
            
            # odm
            sudo sed -i '/^odm \/odm ext4/a odm\t/odm\terofs\tro\twait,,avb,logical,first_stage_mount' "$target"
            
            echo "Done, now $STOCK_DEVICE is EROFS-enabled."
        else
            echo "- Omitted: $fstab not found"
        fi
    done

    echo "--- EROFS patching completed ---"
}

INSTALL_FRAMEWORK() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <framework-res.apk>"
        return 1
    fi

    local framework_res_apk="$1"

    # echo "Checking framework-res.apk integrity..."
    # if ! unzip -t "$framework_res_apk" >/dev/null 2>&1; then
    #     echo "Warning: $framework_res_apk failed integrity check, using fallback from bin/framework-res.apk"
    #     cp -f "$(pwd)/bin/framework-res.apk" "$framework_res_apk"
    # fi

    # Installing stock overlay
    echo "Installing Framework..."
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

    echo "Decompiling: $FILE"
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

    echo "Recompiling: $DECOMPILED_DIR"
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
        echo "- Pattern not found: $FROM"
        return 1
    }

    echo "- Patching: $FILE"
    echo "- From $FROM to $TO"
    [ -f "$FILE.bak" ] || cp "$FILE" "$FILE.bak"

    xxd -p -c 0 "$FILE" | sed "s/$FROM/$TO/" | xxd -r -p > "$FILE.tmp" &&
    mv "$FILE.tmp" "$FILE"

    xxd -p -c 0 "$FILE" | grep -q "$TO" && {
        echo "- Patch success"
        rm -rf "$FILE.bak"        
        return 0
    }

    echo "- Patch failed, restoring backup"
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

    echo "Patching Bluetooth library."
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
        echo "- No known Bluetooth patch pattern matched."
		rm -rf "$BT_LIB_FILE"
        return 1
    fi

    return 0
}


FIX_VNDK() {
    echo "- Checking $STOCK_DEVICE and $TARGET_DEVICE vndk version."
    if [ -f "$TARGET_ROM_SYSTEM_EXT_DIR/apex/com.android.vndk.v${STOCK_VNDK_VERSION}.apex" ]; then
        echo "- VNDK matched."
    else
        echo "- VNDK mismatch or missing."
        rm -f "$TARGET_ROM_SYSTEM_EXT_DIR/apex/com.android.vndk"*.apex
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
	    echo "Fixing system_ext according to $STOCK_DEVICE"
        echo "- Copying system_ext content into system root"
		rm -rf "$EXTRACTED_FIRM_DIR/system/system_ext"
        cp -a --preserve=all "$EXTRACTED_FIRM_DIR/system_ext" "$EXTRACTED_FIRM_DIR/system"

        echo "- Cleaning and merging system_ext file contexts and configs"
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


FIX_SELINUX() {
    echo ""
    local SELINUX_FILE="$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/mapping/${STOCK_VNDK_VERSION}.0.cil"

    # Self explanatory, fixes selinux that prevents booting
    if [ ! -f "$SELINUX_FILE" ]; then
        echo "Error: SELinux file not found at $SELINUX_FILE"
        return 1
    fi

    echo "Fixing selinux for $STOCK_DEVICE."

    UNSUPPORTED_SELINUX=("audiomirroring" "fabriccrypto" "hal_dsms_default" "qb_id_prop" "hal_dsms_service" "proc_compaction_proactiveness" "sbauth" "ker_app" "kpp_app" "kpp_data" "attiqi_app" "kpoc_charger")

    for keyword in "${UNSUPPORTED_SELINUX[@]}"; do
        if grep -q "$keyword" "$SELINUX_FILE"; then
            sed -i "/$keyword/d" "$SELINUX_FILE"
        fi
    done

	REMOVE_LINE '(genfscon proc "/sys/kernel/firmware_config" (u object_r proc_fmw ((s0) (s0))))' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_sepolicy.cil"
	REMOVE_LINE '(genfscon proc "/sys/vm/compaction_proactiveness" (u object_r proc_compaction_proactiveness ((s0) (s0))))' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_sepolicy.cil"
    REMOVE_LINE 'init.svc.vendor.wvkprov_server_hal                           u:object_r:wvkprov_prop:s0' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_property_contexts"
}


UPDATE_FLOATING_FEATURE() {
    local key="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo "⛔️️ Skipping $key — no value found."
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
        echo "✳️ Updated $key with => $value"
    else
        local line="    <$key>$value</$key>"
        sed -i "3i\\$line" "$TARGET_FLOATING_FEATURE"
        echo "✅️ Added $key with value => $value"
    fi
}


APPLY_FLOATING_FEATURE() {
    echo ""
	echo "============ Floating Feature ============"
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

    #========== BATTERY ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_ENABLE_EU_BATTERY_REGULATORY" "TRUE"

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
    echo "- Removing ESIM files."
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
    echo "- Removing fabric crypto."
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
        echo "JDM detected → debloating unnecessary files"
        rm -rf -- "$EXTRACTED_FIRM_DIR/system/system/app/BluetoothAgent"
        rm -rf -- "$EXTRACTED_FIRM_DIR/system/system/app/BluetoothMidiService"
        rm -rf -- "$EXTRACTED_FIRM_DIR/system/system/priv-app/SamsungCamera"
    else
        echo "Device is not JDM → skipping JDM debloating"
    fi

    shopt -u nocasematch
}

APPLY_STOCK_CONFIG() {
    echo ""
	echo "Applying $STOCK_DEVICE device config."
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    if [ ! -f "$DEVICES_DIR/$STOCK_DEVICE/config" ]; then
        echo "- Config file for $STOCK_DEVICE not found in $DEVICES_DIR"
        return 1
	fi

    if [ -f "$DEVICES_DIR/$STOCK_DEVICE/config" ]; then
        echo "- $STOCK_DEVICE config found."
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

	# FIX SELINUX.
	FIX_SELINUX

    # Floating Feature.
    APPLY_FLOATING_FEATURE

    # Fix unsupported BPF error for kernels lower than 5.10.
    if [ "$USE_UI_8_TETHERING_APEX" = "True" ]; then
        cp -rfa "$(pwd)/LumiROM/Mods/device_specific/bpf_patch/." "$EXTRACTED_FIRM_DIR/"
    fi

	# Replace Stock Files.
	rm -rf $EXTRACTED_FIRM_DIR/product/overlay/framework-res*auto_generated_rro_product.apk
    cp -af "$DEVICES_DIR/$STOCK_DEVICE/Stock/." "$EXTRACTED_FIRM_DIR/"
}


DEBLOAT_APPS=("FactoryCameraFB" "HybridRadio" "CIDManager" "SBrowser" "Facebook_stub_TFN" "FBAppManager_TFN" "SamsungTTSVoice_es_US_l01 " "SamsungCalendar" "KTAuth_Stub" "GameTools_Dream" "Gmail2" "Maps" "Duo" "Velvet" "CarrierDefaultApp" "ccinfo" "Chrome" "ChromeCustomizations" "GameHome" "GameOptimizingService" "WlanTest" "AssistantShell" "HotwordEnrollmentOKGoogleEx4CORTEXM55" "HotwordEnrollmentXGoogleEx4CORTEXM55" "BardShell" "DuoStub" "GoogleCalendarSyncAdapter" "AndroidDeveloperVerifier" "AndroidGlassesCore" "SOAgent77" "YourPhone_Stub" "AndroidAutoStub" "SingleTakeService" "SamsungBilling" "AndroidSystemIntelligence" "GoogleRestore" "SamsungMessages" "SamsungPositioning" "YouTube"  "SearchSelector" "AirGlance" "AirReadingGlass" "SamsungTTS" "WlanTest" "ARCore" "ARDrawing" "ARZone" "BGMProvider" "BixbyWakeup" "BlockchainBasicKit" "Cameralyzer" "DictDiotekForSec" "EasymodeContactsWidget81" "Fast" "FBAppManager_NS" "FunModeSDK" "GearManagerStub" "KidsHome_Installer" "LinkSharing_v11" "LiveDrawing" "MAPSAgent" "MdecService" "MinusOnePage" "MoccaMobile" "Netflix_stub" "Notes40" "ParentalCare" "PhotoTable" "PlayAutoInstallConfig" "SamsungPassAutofill_v1" "SamsungTTSVoice_de_DE_f00" "SamsungTTSVoice_el_GR_f00" "SamsungTTSVoice_en_GB_f00" "SamsungTTSVoice_en_US_f00" "SamsungTTSVoice_en_US_l03" "SamsungTTSVoice_es_ES_f00" "SamsungTTSVoice_es_MX_f00" "SamsungTTSVoice_es_US_f00" "SamsungTTSVoice_fr_FR_f00" "SamsungTTSVoice_hi_IN_f00" "SamsungTTSVoice_it_IT_f00" "SamsungTTSVoice_pl_PL_f00" "SamsungTTSVoice_pt_BR_f00" "SamsungTTSVoice_ru_RU_f00" "SamsungTTSVoice_th_TH_f00" "SamsungTTSVoice_vi_VN_f00" "SamsungTTSVoice_en_IN_f00" "SmartReminder" "SmartSwitchStub" "UnifiedWFC" "UniversalMDMClient" "VideoEditorLite_Dream_N" "VisionIntelligence3.7" "VoiceAccess" "VTCameraSetting" "WebManual" "WifiGuider" "KTAuth" "KTCustomerService" "KTUsimManager" "LGUMiniCustomerCenter" "LGUplusTsmProxy" "SamsungTTSVoice_ko_KR_r00" "SketchBook" "SKTMemberShip_new" "SktUsimService" "TWorld" "AirCommand" "AppUpdateCenter" "AREmoji" "AREmojiEditor" "AuthFramework" "AutoDoodle" "AvatarEmojiSticker" "AvatarEmojiSticker_S" "Bixby" "BixbyInterpreter" "BixbyVisionFramework3.5" "DevGPUDriver-EX2200" "DigitalKey" "Discover" "DiscoverSEP" "EarphoneTypeC" "EasySetup" "FBInstaller_NS" "FBServices" "FotaAgent" "GalleryWidget" "GameDriver-EX2100" "GameDriver-EX2200" "GameDriver-SM8150" "HashTagService" "MultiControlVP6" "LedCoverService" "LinkToWindowsService" "LiveStickers" "MemorySaver_O_Refresh" "MultiControl" "OMCAgent5" "OneDrive_Samsung_v3" "OneStoreService" "SamsungCarKeyFw" "SamsungPass" "SettingsBixby" "SetupIndiaServicesTnC" "SKTFindLostPhone" "SKTHiddenMenu" "SKTMemberShip" "SKTOneStore" "SktUsimService" "SmartEye" "SmartPush" "SmartThingsKit" "SmartTouchCall" "SOAgent7" "SOAgent75" "SolarAudio-service" "SPPPushClient" "sticker" "StickerFaceARAvatar" "StoryService" "SumeNNService" "SVoiceIME" "SwiftkeyIme" "SwiftkeySetting" "SystemUpdate" "TADownloader" "TalkbackSE" "TaPackAuthFw" "TPhoneOnePackage" "TPhoneSetup" "TWorld" "UltraDataSaving_O" "Upday" "UsimRegistrationKOR" "YourPhone_P1_5" "AvatarPicker" "KT114Provider2" "KTHiddenMenu" "KTOneStore" "KTServiceAgent" "KTServiceMenu" "LGUGPSnWPS" "LGUHiddenMenu" "LGUOZStore" "SKTFindLostPhoneApp" "SmartPush_64" "SOAgent76" "TService" "vexfwk_service" "VexScanner" "LiveEffectService" "YourPhone_P1_5" "vexfwk_service" "AutoHotspotMDE")

KICK() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    
	local EXTRACTED_FIRM_DIR="$1"

    echo "- Debloating apps."
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
    echo "Debloating."
    KICK "$EXTRACTED_FIRM_DIR"
    REMOVE_ESIM_FILES "$EXTRACTED_FIRM_DIR"
	REMOVE_FABRIC_CRYPTO "$EXTRACTED_FIRM_DIR"
    JDM_DEBLOAT "$EXTRACTED_FIRM_DIR"
    DEODEX "$EXTRACTED_FIRM_DIR"
	echo "- Deleting unnecessary files and folders."
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/boot-image.bprof"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/boot-image.prof"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/hidden"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/preload"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/tts"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/mediasearch"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/MediaSearch"


    if [[ "$STOCK_DEVICE" == "SM-A225F" || "$STOCK_DEVICE" == "SM-A225M" ]]; then
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/libnfc-sec.so"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/libnfc_sec_jni.so"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib/libnfc_sec_jni.so"
        echo "Removed NFC from stock image"
    fi
    
}

DEODEX() {
    echo "- Deodexing ROM (removing oat folders)..."
    echo "  > OAT folders to remove:"
    find "$EXTRACTED_FIRM_DIR/system/system_ext/priv-app" -type d -name "oat" | sed "s|$EXTRACTED_FIRM_DIR/|    - |"
    sudo find "$EXTRACTED_FIRM_DIR/system/system_ext/priv-app" -type d -name "oat" -exec rm -rf {} +
    find "$EXTRACTED_FIRM_DIR/system/system_ext/app" -type d -name "oat" | sed "s|$EXTRACTED_FIRM_DIR/|    - |"
    sudo find "$EXTRACTED_FIRM_DIR/system/system_ext/app" -type d -name "oat" -exec rm -rf {} +
    find "$EXTRACTED_FIRM_DIR/system/system/priv-app" -type d -name "oat" | sed "s|$EXTRACTED_FIRM_DIR/|    - |"
    sudo find "$EXTRACTED_FIRM_DIR/system/system/priv-app" -type d -name "oat" -exec rm -rf {} +
    find "$EXTRACTED_FIRM_DIR/system/system/app" -type d -name "oat" | sed "s|$EXTRACTED_FIRM_DIR/|    - |"
    sudo find "$EXTRACTED_FIRM_DIR/system/system/app" -type d -name "oat" -exec rm -rf {} +

    echo "  > Deodex complete"
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
            echo " Removed: $KEY"
        else
            if sudo grep -q "^${KEY}=" "$PROP"; then
                sudo sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$PROP"
                echo " Updated: $KEY=$VALUE"
            else
                echo "${KEY}=${VALUE}" | sudo tee -a "$PROP" > /dev/null
                echo " Added: $KEY=$VALUE"
            fi
        fi
    done
}


APPLY_FEATURES() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"

    # Add build.prop features
    echo "Applying useful features."
	echo " Adding build prop tweak."
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.frp.pst"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.product.locale" "en-US"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "wifi.interface" "wlan0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "wlan.wfd.hdcp" "disabled"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.hwui.renderer" "skiavk"
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.telephony.sim_slots.count" "2"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.surface_flinger.protected_contents" "true"
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
	

    if [ "$BUILD_STATUS" == "OFFICIAL" ]; then
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lumirom.official" "true"
    else
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.lumirom.official" "false"
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
                echo "Updated ro.build.display.id in $PROP"
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

GEN_FS_CONFIG() {
    local EXTRACTED_FIRM_DIR="${1%/}"

    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [[ -d "$ROOT" ]] || continue
        PARTITION=$(basename "$ROOT")
        [[ "$PARTITION" == "config" ]] && continue

        local FS_CONFIG="$EXTRACTED_FIRM_DIR/config/${PARTITION}_fs_config"

        echo "--- Synchronizing $PARTITION ---"

        if [[ "$PARTITION" == "vendor" ]]; then
            echo "  [*] Fixing vendor_fs_config..."
            
            local TMP_CLEAN=$(mktemp)
            
            sudo awk '{
                gsub(/^\//, "", $1);
                if (length($4) == 4 && substr($4, 1, 1) == "0") $4 = substr($4, 2);
                if ($1 ~ /^(vendor|lost)/ && NF >= 4) {
                    print $1, $2, $3, $4
                }
            }' "$FS_CONFIG" > "$TMP_CLEAN"
            
            # Script removes it, so hardcoded to be added again
            echo "/ 0 2000 755" >> "$TMP_CLEAN"
            echo "vendor/lost+found 0 0 700" >> "$TMP_CLEAN"
            echo "vendor/bin/toolbox 0 2000 755" >> "$TMP_CLEAN"
            
            sort -k1,1 -u "$TMP_CLEAN" | sudo tee "$FS_CONFIG" > /dev/null
            
            rm "$TMP_CLEAN"
            echo "  [+] vendor_fs_config fixed."
        fi
        
        if [[ ! -f "$FS_CONFIG" ]]; then
            echo "--- Creating new fs_config for $PARTITION ---"
            echo "$PARTITION 0 0 0755" | sudo tee "$FS_CONFIG" > /dev/null
        fi

        sudo find "$ROOT" -mindepth 1 -printf "$PARTITION/%P\n" | while read -r ENTRY; do
            [[ -z "$ENTRY" ]] && continue
            
            if ! grep -qF "$ENTRY " "$FS_CONFIG"; then
                local REL_PATH="${ENTRY#$PARTITION/}"
                if [[ -d "$ROOT/$REL_PATH" ]]; then
                    echo "  [+] Adding DIR: $ENTRY"
                    echo "$ENTRY 0 0 0755" | sudo tee -a "$FS_CONFIG" > /dev/null
                else
                    echo "  [+] Adding FILE: $ENTRY"
                    echo "$ENTRY 0 0 0644" | sudo tee -a "$FS_CONFIG" > /dev/null
                fi
            fi
        done
    done
}

GEN_FILE_CONTEXTS() {
    local EXTRACTED_FIRM_DIR="${1%/}"

    sudo chown -R $USER:$USER "$EXTRACTED_FIRM_DIR/config/"
    sudo chmod -R 755 "$EXTRACTED_FIRM_DIR/config/"

    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [[ -d "$ROOT" ]] || continue
        PARTITION=$(basename "$ROOT")
        [[ "$PARTITION" == "config" ]] && continue

        local FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/${PARTITION}_file_contexts"
        [[ ! -f "$FILE_CONTEXTS" ]] && touch "$FILE_CONTEXTS"

        echo "--- Syncing contexts for: $PARTITION ---"
        
        local TMP_EXISTING=$(mktemp)
        sed 's/\\//g' "$FILE_CONTEXTS" | awk '{print $1}' > "$TMP_EXISTING"

        sudo find "$ROOT" -mindepth 1 \( -type f -o -type d \) -printf "/$PARTITION/%P\n" | while read -r PATH_ENTRY; do
            
            if ! grep -qxFe "$PATH_ENTRY" "$TMP_EXISTING" 2>/dev/null; then
                echo "  [+] Context for: $PATH_ENTRY"
                
                local CONTEXT="u:object_r:system_file:s0"

                if [[ "$PARTITION" == "vendor" ]]; then
                    CONTEXT="u:object_r:vendor_file:s0"
                
                elif [[ "$PARTITION" == "system" || "$PARTITION" == "product" ]]; then
                    if [[ "$PATH_ENTRY" == *.so ]]; then
                        CONTEXT="u:object_r:system_lib_file:s0"
                    else
                        CONTEXT="u:object_r:system_file:s0"
                    fi
                fi

                local ESCAPED_PATH=$(echo "$PATH_ENTRY" | sed -e 's/[.+]/\\&/g')
                
                if ! echo "$ESCAPED_PATH $CONTEXT" >> "$FILE_CONTEXTS" 2>/dev/null; then
                    echo "$ESCAPED_PATH $CONTEXT" | sudo tee -a "$FILE_CONTEXTS" > /dev/null
                fi
                
                echo "$PATH_ENTRY" >> "$TMP_EXISTING"
            fi
        done
        rm "$TMP_EXISTING"
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
    local OP_LIST="$(pwd)/template/dynamic_partitions_op_list"

    if [[ -f "$DEVICE_CONFIG" ]]; then
        local SUPER_SIZE=$(grep "STOCK_SUPER_SIZE" "$DEVICE_CONFIG" | cut -d'=' -f2 | tr -d '[:space:]')
        
        # Update the super size on the list according to the device
        if [[ -n "$SUPER_SIZE" && -f "$OP_LIST" ]]; then
            echo -e "\e[32mUpdating super size on op_list: $SUPER_SIZE bytes\e[0m"
            sed -i "s/^add_group samsung_dynamic_partitions .*/add_group samsung_dynamic_partitions $SUPER_SIZE/" "$OP_LIST"
        else
            echo "Warning: STOCK_SUPER_SIZE hasn't been found on $DEVICE_CONFIG"
        fi
    else
        echo "Error: config file not found"
    fi


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
            local MOUNT_POINT="/$PARTITION"

            echo ""
            [[ -f "$FS_CONFIG" ]] || { echo "Warning: $FS_CONFIG missing, skipping $PARTITION"; exit 0; }
            [[ -f "$FILE_CONTEXTS" ]] || { echo "Warning: $FILE_CONTEXTS missing, skipping $PARTITION"; exit 0; }

            sudo sort -u "$FILE_CONTEXTS" -o "$FILE_CONTEXTS"
            sudo sort -u "$FS_CONFIG" -o "$FS_CONFIG"
            sudo chown -R $(whoami):$(whoami) "${EXTRACTED_FIRM_DIR}"/vendor/

            if [[ "$FILE_SYSTEM" == "erofs" ]]; then
                echo -e "\e[33mBuilding EROFS image:\e[0m $OUT_IMG"
                sudo $(pwd)/bin/erofs-utils/mkfs.erofs --mount-point="$MOUNT_POINT" --fs-config-file="$FS_CONFIG" --file-contexts="$FILE_CONTEXTS" -z lz4hc -b 4096 -T 1640995200 "$OUT_IMG" "$SRC_DIR" >/dev/null 2>&1
                sudo chown -R $(whoami):$(whoami) "$OUT_IMG"
            else
                echo "Unknown filesystem: $FILE_SYSTEM, skipping $PARTITION"
            fi
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
            echo -e "\e[32mUpdating size of $PARTITION in op_list: $ACTUAL_SIZE bytes\e[0m"
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
        echo "Error: img2sdat binary not found at $IMG2SDAT_BIN"
        return 1
    fi

    chmod +x "$IMG2SDAT_BIN"

    # This is for compressing to .new.dat
    echo "=== Converting IMG to SDAT ==="

    for f in "$IMG_DIR"/*.img; do
        [[ -f "$f" ]] || continue
        PARTITION="$(basename "$f" .img)"

        (
            echo "Converting $PARTITION.img..."
            "$IMG2SDAT_BIN" -o "$TMP_DIR" -B "$TMP_DIR/$PARTITION.map" "$f" > /dev/null 2>&1
            touch "$TMP_DIR/$PARTITION.patch.dat"
            echo "Created patch.dat for $PARTITION"
        ) &
    done

    wait

    # Compress it to .new.dat.br to make later a .zip file
    echo ""
    echo "=== Compressing DAT files with Brotli (Parallel) ==="

    local JOBS=4 # Set to match vCPUs
    for DAT in "$TMP_DIR"/*.new.dat; do
        [[ -f "$DAT" ]] || continue
        PARTITION="$(basename "$DAT" .new.dat)"
        OUT_FILE="$TMP_DIR/$PARTITION.new.dat.br"

        (
            echo "Compressing $PARTITION.new.dat..."
            brotli -f -q 1 --output="$OUT_FILE" "$DAT"
            echo "Finished $PARTITION.new.dat.br"
        ) &

        # Limit concurrent jobs
        while [ $(jobs -r | wc -l) -ge "$JOBS" ]; do
            sleep 1
        done
    done

    wait
    echo ""
    echo "All partitions converted and compressed successfully."
}
