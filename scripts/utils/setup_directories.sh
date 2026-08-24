#!/bin/bash

source scripts/utils/bash_colors.sh

set -e

echo "Running script: $(basename "$0")"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <dir1> <dir2> ... <dirN>"
    exit 1
fi

for DIR in "$@"; do
    # Check if directory exists
    if [ ! -d "$DIR" ]; then
        mkdir -p "$DIR"
        echo "${GREEN}Directory created:${RESET} $DIR"
    else
        echo "${YELLOW}Directory already exists:${RESET} $DIR"
    fi
done

mkdir -p "makerom"
cp -r template/* "makerom"/
