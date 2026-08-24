#!/bin/bash

set -e

DESTINY="$1"

GOFILE_UPLOAD() {
    local FILE="$1"
    local URL_VAR="$2"

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

    if [ -n "$GITHUB_ENV" ] && [ -n "$URL_VAR" ]; then
        echo "${URL_VAR}=$LINK" >> "$GITHUB_ENV"
    fi
}

UPLOAD_FILE() {
    local FILE="$1"
    local URL_VAR="$2"

    case "$DESTINY" in
        huggingface)
            echo "Uploading $(basename "$FILE") to Hugging Face"
            local REMOTE_PATH="ROMs/$LUMIROM_VERSION/$STOCK_DEVICE/$(basename "$FILE")"
            python3 "$(dirname "$0")/upload_hf.py" "$FILE" "$REMOTE_PATH"
            if [ -n "$GITHUB_ENV" ] && [ -n "$HF_USER" ]; then
                echo "${URL_VAR}=https://huggingface.co/buckets/${HF_USER}/LumiROM/resolve/${REMOTE_PATH}?download=true" >> "$GITHUB_ENV"
            fi
            ;;

        gofile)
            echo "Uploading $(basename "$FILE") to GoFile"
            GOFILE_UPLOAD "$FILE" "$URL_VAR"
            ;;

        *)
            echo "Error: Pick 'huggingface' or 'gofile'."
            exit 1
            ;;
    esac
}

FOUND_ZIPS=$(find ./ROM/"$FOLDER_NAME" -type f -name "*.zip" 2>/dev/null)

if [ -z "$FOUND_ZIPS" ]; then
    echo "ERROR: No zip files found in ROM/$FOLDER_NAME."
    exit 1
fi

while IFS= read -r ZIP_PATH; do
    if [[ "$(basename "$ZIP_PATH")" == *"INCREMENTAL"* ]]; then
        UPLOAD_FILE "$ZIP_PATH" "DOWNLOAD_URL_INCREMENTAL"
    else
        UPLOAD_FILE "$ZIP_PATH" "DOWNLOAD_URL"
    fi
done <<< "$FOUND_ZIPS"
