#!/usr/bin/env bash

source "$(pwd)/scripts/utils/bash_colors.sh"

GEN_KEYS() {
    local MODE="${1:-platform}"
    local OUTPUT_DIR="${2:-$HOME/.lumi/keys}"

    if [ "$#" -gt 2 ]; then
        echo "Usage: ${FUNCNAME[0]} [platform|ota] [OUTPUT_DIR]"
        echo "  MODE        Which keypair to generate: platform (default) or ota"
        echo "  OUTPUT_DIR  Where to store the generated keys (default: ~/.lumi/keys)"
        return 1
    fi

    if [[ "$MODE" != "platform" && "$MODE" != "ota" ]]; then
        echo "${RED}Unsupported mode:${RESET} $MODE (use platform or ota)"
        return 1
    fi

    local CN COT
    if [[ "$MODE" == "platform" ]]; then
        CN="LumiROM Platform"
        COT="platform"
    else
        CN="LumiROM ota"
        COT="ota"
    fi

    mkdir -p "$OUTPUT_DIR"
    chmod 700 "$OUTPUT_DIR"

    if [ -f "$OUTPUT_DIR/$MODE.pk8" ] && [ -f "$OUTPUT_DIR/$MODE.x509.pem" ]; then
        echo "${YELLOW}$MODE keys already exist in $OUTPUT_DIR.${RESET}"
        echo "${YELLOW}Remove them first to regenerate, or reuse as-is.${RESET}"
        return 0
    fi

    echo "${YELLOW}Generating LumiROM $MODE key pair (RSA-4096)...${RESET}"
    openssl genrsa -out "$OUTPUT_DIR/$MODE.pem" 4096 2>/dev/null
    openssl req -new -x509 -key "$OUTPUT_DIR/$MODE.pem" \
        -out "$OUTPUT_DIR/$MODE.x509.pem" -sha256 -days 10000 \
        -subj "/C=US/ST=LumiROM/L=LumiROM/O=LumiROM/OU=$COT/CN=$CN" \
        2>/dev/null
    openssl pkcs8 -topk8 -outform DER -nocrypt \
        -in "$OUTPUT_DIR/$MODE.pem" -out "$OUTPUT_DIR/$MODE.pk8" 2>/dev/null

    chmod 600 "$OUTPUT_DIR/$MODE.pem" "$OUTPUT_DIR/$MODE.pk8"
    chmod 644 "$OUTPUT_DIR/$MODE.x509.pem"

    rm -f "$OUTPUT_DIR/$MODE.pem"

    echo "${GREEN}Generated $MODE keys in $OUTPUT_DIR:${RESET}"
    ls -la "$OUTPUT_DIR"
}