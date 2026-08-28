#!/bin/bash

source "$(pwd)/scripts/utils/bash_colors.sh"

# Prints the PEM of the platform certificate that will be used for this build:
#   - $PLATFORM_CERT (secret, CI official) if set
#   - $HOME/.lumi/keys/platform.x509.pem (user's own key) if present
#   - the AOSP testkey otherwise (unofficial builds)
GET_ACTIVE_PLATFORM_CERT() {
    if [ -n "$PLATFORM_CERT" ]; then
        printf '%s' "$PLATFORM_CERT"
    elif [ -f "$HOME/.lumi/keys/platform.x509.pem" ]; then
        cat "$HOME/.lumi/keys/platform.x509.pem"
    else
        cat "$(pwd)/scripts/keys/testkey.x509.pem"
    fi
}

# Prints the SHA-256 (hex) of the DER-encoded active platform certificate.
GET_ACTIVE_CERT_HASH() {
    GET_ACTIVE_PLATFORM_CERT | sed "/CERTIFICATE/d" | tr -d "\n" | base64 -d | sha256sum | cut -d ' ' -f 1
}

# Returns 0 (true) if the active platform certificate is NOT the AOSP testkey,
# i.e. it is LumiROM's own platform key.
IS_CUSTOM_PLATFORM_KEY() {
    local TESTKEY_HASH
    TESTKEY_HASH="$(sed "/CERTIFICATE/d" "$(pwd)/scripts/keys/testkey.x509.pem" | tr -d "\n" | base64 -d | sha256sum | cut -d ' ' -f 1)"

    local ACTIVE_HASH
    ACTIVE_HASH="$(GET_ACTIVE_CERT_HASH)"

    if [ -n "$ACTIVE_HASH" ] && [ "$ACTIVE_HASH" != "$TESTKEY_HASH" ]; then
        return 0
    fi

    return 1
}

# Prints the DER hex of the active platform certificate (used to inject into
# services.jar as the custom platform signature).
GET_ACTIVE_CERT_HEX() {
    GET_ACTIVE_PLATFORM_CERT | sed "/CERTIFICATE/d" | tr -d "\n" | base64 -d | xxd -p -c 0
}

# Materializes the active platform key (private key + certificate) into a
# directory and prints that directory path. Uses:
#   - $PLATFORM_PK8/$PLATFORM_CERT (secrets, CI official) if set
#   - $HOME/.lumi/keys if present
#   - the AOSP testkey otherwise (unofficial builds)
GET_ACTIVE_KEY_FILES() {
    local KEY_DIR

    if [ -n "$PLATFORM_PK8" ] && [ -n "$PLATFORM_CERT" ]; then
        KEY_DIR="$(mktemp -d)"
        printf '%s' "$PLATFORM_PK8" | base64 -d > "$KEY_DIR/platform.pk8"
        printf '%s' "$PLATFORM_CERT" > "$KEY_DIR/platform.x509.pem"
    elif [ -f "$HOME/.lumi/keys/platform.pk8" ] && [ -f "$HOME/.lumi/keys/platform.x509.pem" ]; then
        KEY_DIR="$HOME/.lumi/keys"
    else
        KEY_DIR="$(pwd)/scripts/keys"
    fi

    echo "$KEY_DIR"
}