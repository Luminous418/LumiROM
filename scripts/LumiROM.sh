#!/bin/bash
set -e

echo "LumiROM build script initialized"

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

    echo "$ROM_TAG"
}

DISABLE_FBE() {
    local FIRM_DIR="$1"

    for fstab in "$FIRM_DIR"/vendor/etc/fstab.mt*; do
        [ -f "$fstab" ] || continue

        sed -i 's/,inlinecrypt//g' "$fstab"
        sed -i 's/inlinecrypt,//g' "$fstab"
        sed -i 's/fileencryption=[^,[:space:]]*//g' "$fstab"
        sed -i 's/,,/,/g' "$fstab"
    done
}

DELETE_ICCC() {
    local FIRM_DIR="$1"

    find "$FIRM_DIR/vendor" -iname "*iccc*" -delete 2>/dev/null || true
}

DEBLOAT_VENDOR() {
    local FIRM_DIR="$1"

    rm -rf \
    "$FIRM_DIR/vendor/app/Traceur" \
    "$FIRM_DIR/vendor/app/CarrierConfig" \
    2>/dev/null || true
}

PATCH_FSTAB_EROFS() {
    local FIRM_DIR="$1"

    for fstab in "$FIRM_DIR"/vendor/etc/fstab.mt*; do
        [ -f "$fstab" ] || continue

        sed -i 's/ext4/erofs/g' "$fstab"
        sed -i 's/,,/,/g' "$fstab"
    done
}

APPLY_STOCK_CONFIG() {
    local FIRM_DIR="$1"
    echo "Applying stock config to $FIRM_DIR"
}

DEBLOAT() {
    local FIRM_DIR="$1"
    echo "Debloating ROM $FIRM_DIR"
}

APPLY_PROP_FEATURES() {
    local FIRM_DIR="$1"
    echo "Applying prop features $FIRM_DIR"
}

APPENDING_DISPLAY_ID() {
    local FIRM_DIR="$1"
    echo "Updating display ID $FIRM_DIR"
}

INSTALL_FRAMEWORK() {
    local FRAMEWORK_PATH="$1"
    echo "Installing framework $FRAMEWORK_PATH"
}

DECOMPILE() {
    local APKTOOL="$1"
    local INPUT_FILE="$2"
    local WORK_DIR="$3"

    java -jar "$APKTOOL" d -f "$INPUT_FILE" -o "$WORK_DIR"
}

RECOMPILE() {
    local APKTOOL="$1"
    local INPUT_DIR="$2"
    local OUTPUT_DIR="$3"
    local WORK_DIR="$4"

    java -jar "$APKTOOL" b "$INPUT_DIR" -o "$OUTPUT_DIR"
}

BUILD_IMG() {
    local FIRM_DIR="$1"
    local FILESYSTEM="$2"
    local OUT_DIR="$3"

    echo "Building $FILESYSTEM images"
}

IMG_TO_BROTLI() {
    local OUT_DIR="$1"
    local TMP_DIR="$2"

    echo "Converting images to Brotli"
}

export -f IS_OFFICIAL
export -f DISABLE_FBE DELETE_ICCC DEBLOAT_VENDOR PATCH_FSTAB_EROFS
export -f APPLY_STOCK_CONFIG DEBLOAT APPLY_PROP_FEATURES
export -f APPENDING_DISPLAY_ID INSTALL_FRAMEWORK
export -f DECOMPILE RECOMPILE BUILD_IMG IMG_TO_BROTLI
