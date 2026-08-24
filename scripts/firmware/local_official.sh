#!/bin/bash

source scripts/utils/bash_colors.sh

if [ -f .env ]; then
    source .env
fi

IS_LOCAL_OFFICIAL() {

    if [ -z "$LUMIROM_BUILD" ] || [ -z "$OFFICIAL_HASH" ]; then
        echo "${BLUE}[!] Missing environment variables. Using default values.${RESET}"
        export BUILD_STATUS="UNOFFICIAL"
        export ROM_TAG="🛠️ LumiROM Unofficial Build"
        return
    fi

    CURRENT_SIGNATURE=$(printf "%s" "$LUMIROM_BUILD" | sha256sum | cut -d ' ' -f 1)

    if [ "$CURRENT_SIGNATURE" == "$OFFICIAL_HASH" ]; then
        export BUILD_STATUS="OFFICIAL"
        export ROM_TAG="✨ LumiROM Official Build"
    else
        export BUILD_STATUS="UNOFFICIAL"
        export ROM_TAG="🛠️ LumiROM Unofficial Build"
    fi

    echo "${BLUE}--- $ROM_TAG detected ---${RESET}"
}