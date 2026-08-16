#!/bin/bash

set -e

DESTINY="$1"

GOFILE_UPLOAD() {
    FILE="$1"

    if [[ -z "$FILE" || ! -f "$FILE" ]]; then
        echo "ERROR: File hasn't been found."
        exit 1
    fi

    SERVER=$(curl -s https://api.gofile.io/servers | jq -r '.data.servers[0].name')

    if [[ -z "$SERVER" || "$SERVER" == "null" ]]; then
        echo "ERROR: No GoFile server available."
        exit 1
    fi
    LINK=$(curl -# -F "file=@$FILE" "https://${SERVER}.gofile.io/uploadFile" | jq -r '.data.downloadPage')

    echo -e "\nDownload link for the uploaded file:"
    echo "$LINK"
    echo
}

ZIP_PATH=$(find ./ROM/"$FOLDER_NAME" -type f -name "*.zip" | head -n 1)

case "$DESTINY" in
    huggingface)
        echo "Uploading ROM to Hugging Face"
        hf buckets cp "$ZIP_PATH" "hf://buckets/$HF_USER/LumiROM/ROMs/$LUMIROM_VERSION/$STOCK_DEVICE/$(basename "$ZIP_PATH")"
        ;;

    gofile)
        echo "Uploading ROM to GoFile"
        GOFILE_UPLOAD "$ZIP_PATH"
        ;;

    *)
        echo "Error: Pick 'huggingface' or 'gofile'."
        exit 1
        ;;
esac