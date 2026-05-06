#!/bin/bash

source scripts/bash_colors.sh

GALAXY_AI() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    source "scripts/LumiROM.sh"

    local EXTRACTED_FIRM_DIR="$1"
    local STOCK_FLOATING_FEATURE="$DEVICES_DIR/$STOCK_DEVICE/floating_feature.xml"
    local TARGET_FLOATING_FEATURE="$EXTRACTED_FIRM_DIR/system/system/etc/floating_feature.xml"

    if [ "$USE_GALAXY_AI" == "Yes" ]; then
    	echo -e "${GREEN}Adding Galaxy AI${RESET}"

        sed -i '/SEC_FLOATING_FEATURE_COMMON_DISABLE_NATIVE_AI/d' "$TARGET_FLOATING_FEATURE"
        # Adding the Galaxy AI versioning
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SIP_CONFIG_ONEUI_VERSION" "80500"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_CONFIG_AI_PHASE" "20260201"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_CONFIG_AI_VERSION" "20261"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_SUPPORT_AI_AGENT" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_SUPPORT_GENERATIVE_AI" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_CONFIG_FOUNDATION_MODEL" "3B"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_CONFIG_LLM_VERSION" "0.70"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.sys.composition.type" "gpu"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.sys.purgeable_assets" "1"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.config.fha_enable" "true"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.vendor.mtk_tflite_support" "1"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.mtk_tflite.target_gpu" "1"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.sys.storage_manager.enabled" "1"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.vpp.enable" "1"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.sys.videoplayer.vpp" "0"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.sys.aicp.enable" "true"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.sys.vsw.enable" "true"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.hwui.render_dirty_regions" "false"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.videoeditor.support_audio_eraser" "1"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.videoeditor.support_object_eraser" "1"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "com.samsung.android.media.contextanalyzer.core" "cpu"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.hwui.texture_cache_size" "72"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.hwui.layer_cache_size" "48"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.vendor.camera.hal3.enabled" "1"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "vendor.camera.hal3.enabled" "1"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.vendor.camera.raw.enabled" "1"
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "persist.sys.camera.raw" "1"

        # Adding AI dependencies
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_OFFLINE_LANGUAGEMODEL" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_PERSONALIZED_DATA_CORE" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SAIV_SUPPORT_AI_REVITAL" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SAIV_CONFIG_AI_REVITAL_VERSION" "1.9,4"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_C2PA" "FALSE"

        # Misc AI things
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_VISION_SUPPORT_AI_MY_FAVORITE_CONTENTS" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_IMAGE_CLIPPER" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_OBJECT_ERASER" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_REFLECTION_ERASER" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_SHADOW_ERASER" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_SMART_LASSO" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_SPOT_FIXER" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_STYLE_TRANSFER" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SYSTEMUI_SUPPORT_BRIEF_NOTIFICATION" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_MMFW_SUPPORT_MEDIA_CONTEXT_ANALYZER" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_MMFW_SUPPORT_TARGET_TRACKING" "TRUE"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_MMFW_SUPPORT_MUSIC_ALBUMART_3DAUDIO" "TRUE"

        sudo cp -rfa "$(pwd)/LumiROM/Mods/Galaxy_AI/system/system/"* "$EXTRACTED_FIRM_DIR/system/system/"
        sudo cp -rfa "$(pwd)/LumiROM/Mods/Galaxy_AI/vendor/"* "$EXTRACTED_FIRM_DIR/vendor/"


        # Adding Wallpaper AI
        if [ ! -d "$EXTRACTED_FIRM_DIR/product/priv-app/AiWallpaper" ]; then
        	echo -e "${GREEN}Adding Wallpaper AI${RESET}"
            mkdir -p "$EXTRACTED_FIRM_DIR/product/priv-app/AiWallpaper"
            cp -rfa "$(pwd)/LumiROM/Mods/Apps/AiWallpaper/"* "$EXTRACTED_FIRM_DIR/product/priv-app/AiWallpaper/"

            UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_TIME_WEATHER_WALLPAPER" "V7"
            UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LOCKSCREEN_CONFIG_WALLPAPER_STYLE" "VIDEO,GENWEATHER,FLIPSUIT_LOCK"
        fi

        # Adding Photo Editor AI Full
        if [ ! -d "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull" ]; then
        	echo -e "${GREEN}Adding Photo Editor AI Full${RESET}"
            rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/ailasso"
            rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/ailassomatting"
            rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/inpainting"
            rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/objectremoval"
            rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/reflectionremoval"
            rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/shadowremoval"
            rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/style_transfer"
            rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app"/PhotoEditor_*
            cp -rfa "$(pwd)/LumiROM/Mods/Apps/PhotoEditor_AIFull/"* "$EXTRACTED_FIRM_DIR/system/system/"
            unzip -o "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull.zip" -d "$EXTRACTED_FIRM_DIR/system/system/priv-app/" >/dev/null 2>&1
            rm -f "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull.zip"
        fi

        # Adding Now Brief
        echo -e "${GREEN}Adding Now Brief${RESET}"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk"
        wget -O "$EXTRACTED_FIRM_DIR/system/system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk" "https://huggingface.co/buckets/LuminousJD418/LumiROM/resolve/OneUI8.5/SamsungSmartSuggestions.apk?download=true" >/dev/null 2>&1
    else
    	echo
        echo -e "${RED}The use of Galaxy AI for this build have been disabled by the user${RESET}"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_DISABLE_NATIVE_AI" "TRUE"
    fi
}