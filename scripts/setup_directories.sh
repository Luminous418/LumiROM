#!/bin/bash

source scripts/bash_colors.sh

set -e

echo "Running script: $(basename "$0")"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <dir1> <dir2> ... <dirN>"
    exit 1
fi

for DIR in "$@"; do
    # Clean old dir
    rm -rf "$DIR"
    # Recreate dir
    mkdir -p "$DIR"
    # Show result
    echo -e "${GREEN}Directory prepared:${RESET} $DIR"
done
