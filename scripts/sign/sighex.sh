#!/usr/bin/env bash

source "$(pwd)/scripts/utils/bash_colors.sh"

SIG_HEX() {
    local CERT="$1"

    if [ $# -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <platform.x509.pem>"
        echo "  Prints the hex of the DER-encoded certificate, to be injected"
        echo "  into services.jar as the custom platform signature."
        return 1
    fi

    if [ ! -f "$CERT" ]; then
        echo "${RED}File not found: $CERT${RESET}"
        return 1
    fi

    sed "/CERTIFICATE/d" "$CERT" | tr -d "\n" | base64 -d | xxd -p -c 0
}