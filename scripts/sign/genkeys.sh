#!/usr/bin/env bash

source "$(pwd)/scripts/utils/bash_colors.sh"

GEN_KEYS() {
    local OUTPUT_DIR="${1:-$HOME/.lumi/keys}"

    if [ "$#" -gt 1 ]; then
        echo "Usage: ${FUNCNAME[0]} [OUTPUT_DIR]"
        echo "  OUTPUT_DIR  Where to store the generated keys (default: ~/.lumi/keys)"
        return 1
    fi

    mkdir -p "$OUTPUT_DIR"
    chmod 700 "$OUTPUT_DIR"

    if [ -f "$OUTPUT_DIR/platform.pk8" ] && [ -f "$OUTPUT_DIR/platform.x509.pem" ]; then
        echo "${YELLOW}Platform keys already exist in $OUTPUT_DIR.${RESET}"
        echo "${YELLOW}Remove them first to regenerate, or reuse as-is.${RESET}"
        return 0
    fi

    echo "${YELLOW}Generating LumiROM platform keys (RSA-4096)...${RESET}"
    openssl genrsa -out "$OUTPUT_DIR/platform.pem" 4096 2>/dev/null
    openssl req -new -x509 -key "$OUTPUT_DIR/platform.pem" \
        -out "$OUTPUT_DIR/platform.x509.pem" -sha256 -days 10000 \
        -subj "/C=US/ST=LumiROM/L=LumiROM/O=LumiROM/OU=platform/CN=LumiROM Platform" \
        2>/dev/null
    openssl pkcs8 -topk8 -outform DER -nocrypt \
        -in "$OUTPUT_DIR/platform.pem" -out "$OUTPUT_DIR/platform.pk8" 2>/dev/null

    chmod 600 "$OUTPUT_DIR/platform.pem" "$OUTPUT_DIR/platform.pk8"
    chmod 644 "$OUTPUT_DIR/platform.x509.pem"

    rm -f "$OUTPUT_DIR/platform.pem"

    echo "${GREEN}Generated keys in $OUTPUT_DIR:${RESET}"
    ls -la "$OUTPUT_DIR"
}