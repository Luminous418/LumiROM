#!/bin/bash

source scripts/bash_colors.sh

VALIDATION() {
    SUPPORTED_DEVICES=(LumiROM/Devices/*)

    # STOCK_DEVICE
    if [ -z "$STOCK_DEVICE" ]; then
        echo "${RED}Error:${RESET} STOCK_DEVICE is not set."
        exit 1
    fi

    if [[ ! " ${SUPPORTED_DEVICES[@]} " =~ " LumiROM/Devices/$STOCK_DEVICE " ]]; then
        echo "${RED}Error:${RESET} STOCK_DEVICE must be supported by the script. Check ${BLUE}LumiROM/Devices${RESET} for supported devices."
        exit 1
    fi

    # TARGET_DEVICE
    if [ -z "$TARGET_DEVICE" ]; then
        echo "${RED}Error:${RESET} TARGET_DEVICE is not set."
        exit 1
    fi

    if [[ ! "$TARGET_DEVICE" =~ ^SM- ]]; then
        echo "${RED}Error:${RESET} TARGET_DEVICE must start with 'SM-'."
        exit 1
    fi

    # TARGET_CSC
    if [ -z "$TARGET_CSC" ]; then
        echo "${RED}Error:${RESET} TARGET_CSC is not set."
        exit 1
    fi

    if [[ ! "$TARGET_CSC" =~ ^[A-Za-z]{3}$ ]]; then
        echo "${RED}Error:${RESET} TARGET_CSC must be 3-character."
        exit 1
    fi

    # TARGET_IMEI
    if [ -z "$TARGET_IMEI" ]; then
        echo "${RED}Error:${RESET} TARGET_IMEI is not set."
        echo "${CYAN}Tip:${RESET} Check inside the script if you don't know what IMEI to put there"
        exit 1
    fi

    if [[ ! "$TARGET_IMEI" =~ ^[0-9]{15}$ ]]; then
        echo "${RED}Error:${RESET} TARGET_IMEI must be a 15-digit number."
        echo "${CYAN}Tip:${RESET} Check inside the script if you don't know what IMEI to put there"
        exit 1
    fi

    # USE_MODS
    if [ -z "$USE_MODS" ]; then
        USE_MODS="Yes"
        echo "${YELLOW}Warning:${RESET} USE_MODS not set. Defaulting to ${GREEN}'Yes'${RESET}."
    fi

    if [ "$USE_MODS" != "Yes" ] && [ "$USE_MODS" != "No" ]; then
        echo "${RED}Error:${RESET} Invalid value for USE_MODS. Please use 'Yes' or 'No'."
        exit 1
    fi

    # USE_GALAXY_AI
    if [ -z "$USE_GALAXY_AI" ]; then
        USE_GALAXY_AI="Yes"
        echo "${YELLOW}Warning:${RESET} USE_GALAXY_AI not set. Defaulting to ${GREEN}'Yes'${RESET}."
    fi

    if [ "$USE_GALAXY_AI" != "Yes" ] && [ "$USE_GALAXY_AI" != "No" ]; then
        echo "${RED}Error:${RESET} Invalid value for USE_GALAXY_AI. Please use 'Yes' or 'No'."
        exit 1
    fi

    # USE_UI_8_TETHERING_APEX
    if [ -z "$USE_UI_8_TETHERING_APEX" ]; then
        USE_UI_8_TETHERING_APEX="False"
        echo "${YELLOW}Warning:${RESET} USE_UI_8_TETHERING_APEX not set. Defaulting to ${GREEN}'False'${RESET}."
        sleep 2
    fi

    if [ "$USE_UI_8_TETHERING_APEX" != "True" ] && [ "$USE_UI_8_TETHERING_APEX" != "False" ]; then
        echo "${RED}Error:${RESET} Invalid value for USE_UI_8_TETHERING_APEX. Please use 'True' or 'False'."
        exit 1
    fi

    # LUMIROM_MAINTAINER
    if [ -z "$LUMIROM_MAINTAINER" ]; then
        echo "${RED}Error:${RESET} LUMIROM_MAINTAINER is not set."
        echo "${CYAN}Tip:${RESET} Is recommended to put either your GitHub or Telegram username without the @. Also don't put spaces in between."
        exit 1
    fi
}