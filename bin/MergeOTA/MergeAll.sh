#!/bin/bash

source scripts/utils/bash_colors.sh

START_TIME=$(date +%s)
if [ "$1" == "cleanup" ]; then
    echo "Cleaning up work dirs..."
    rm -rf _AP _CSC _images _update_bin
    echo "Done"
elif [ "$1" == "cleanupall" ]; then
    echo "Cleaning up everything..."
    rm -rf _AP _CSC _images _update_bin _odin_extracted out Progress.txt
    echo "Done"
fi
set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 [path to base firmware ZIP] [path to update bin ZIP]"
    exit 1
fi

BASE_ZIP="$1"
UPDATE_ZIP="$2"
echo
echo -e "${CYAN}===== Samsung Beta Firmware Merger =====${RESET}"
echo -e "${GREEN}Base firmware:${RESET} $BASE_ZIP"
echo -e "${GREEN}Update binary:${RESET} $UPDATE_ZIP"
echo

# Check dependencies
for cmd in unzip tar lz4; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "$cmd is not installed. Installing..."
        sudo apt update && sudo apt install -y $cmd
    fi
done

# Extract base firmware zip
echo
echo -e "${YELLOW}Extracting ODIN firmware ZIP...${RESET}"
mkdir -p _odin_extracted
unzip -q "$BASE_ZIP" -d _odin_extracted

# Find AP tar inside base ZIP
echo
AP_TAR=$(find _odin_extracted -type f -name "AP*.tar.md5" | head -n 1)
if [ -z "$AP_TAR" ]; then
    echo "Error: Could not find AP*.tar.md5 in base ZIP!"
    exit 1
fi
echo
BL_TAR=$(find _odin_extracted -type f -name "BL*.tar.md5" | head -n 1)
if [ -z "$BL_TAR" ]; then
    echo "Error: Could not find BL*.tar.md5 in base ZIP!"
fi
echo
CP_TAR=$(find _odin_extracted -type f -name "CP*.tar.md5" | head -n 1)
if [ -z "$CP_TAR" ]; then
    echo "Error: Could not find CP*.tar.md5 in base ZIP!"
fi
echo
CSC_TAR=$(find _odin_extracted -type f -name "CSC*.tar.md5" | head -n 1)
if [ -z "$CSC_TAR" ]; then
    echo "Error: Could not find CSC*.tar.md5 in base ZIP!"
    exit 1
fi
HOME_TAR=$(find _odin_extracted -type f -name "HOME_CSC*.tar.md5" | head -n 1)
if [ -z "$HOME_TAR" ]; then
    echo "Error: Could not find HOME_CSC*.tar.md5 in base ZIP!"
    exit 1
fi
echo -e "${GREEN}Found AP package:${RESET} $AP_TAR"
echo -e "${GREEN}Found BL package:${RESET} $BL_TAR"
echo -e "${GREEN}Found CP package:${RESET} $CP_TAR"
echo -e "${GREEN}Found CSC package:${RESET} $CSC_TAR"
echo -e "${GREEN}Found HOME_CSC package:${RESET} $HOME_TAR"

# Extract super.img.lz4 from AP
echo
mkdir -p _lz4tmp
echo -e "${YELLOW}Extracting super.img.lz4 from AP...${RESET}"
tar -xf "$AP_TAR" --wildcards --no-same-owner -C _lz4tmp 'super.img.lz4'

if [ ! -f _lz4tmp/super.img.lz4 ]; then
    echo -e "${RED}Error: super.img.lz4 not found in AP package!${RESET}"
    exit 1
fi

# De-LZ4
echo
echo -e "${YELLOW}Decompressing lz4 images...${RESET}"
mkdir _images
lz4 -d _lz4tmp/super.img.lz4 _images/super.img
rm -rf _lz4tmp

# Desparse super
echo
echo -e "${YELLOW}Unsparsing super${RESET}"
./bin/MergeOTA/imjtool _images/super.img extract
mv _images/super.img _images/super.img-old 2>/dev/null
mv extracted/image.img _images/super.img
rm -rf extracted

# Extract super
echo
echo -e "${YELLOW}Extracting super${RESET}"
mkdir _images/super
mkdir _images/super/images
./bin/MergeOTA/lpdump _images/super.img > _images/super/superlpdump.txt
./bin/MergeOTA/lpunpack _images/super.img _images/super/images
echo -e "${GREEN}Super extracted${RESET}"

# Parse super
parse_super_partitions() {
    local lpdump_file="$1"
    local partitions=()
    
    echo "Parsing super layout..."
    
    while IFS= read -r line; do
        if [[ $line == *"Name:"* ]]; then
            partition_name=$(echo "$line" | sed 's/.*Name: \([^[:space:]]*\).*/\1/')
            partitions+=("$partition_name")
        fi
    done < "$lpdump_file"
    
    echo "Found partitions in super: ${partitions[*]}"
    echo "${partitions[@]}"
}

extract_super_properties() {
    local lpdump_file="$1"
    
    echo
    echo -e "${YELLOW}Extracting super properties${RESET}"
    
    # Parse the specific format from your lpdump output
    SUPER_SIZE=$(grep "Size:" "$lpdump_file" | grep "bytes" | awk '{print $(NF-1)}')
    METADATA_SIZE=$(grep "Metadata max size:" "$lpdump_file" | awk '{print $4}')
    METADATA_SLOTS=$(grep "Metadata slot count:" "$lpdump_file" | awk '{print $4}')
    
    echo -e "${PURPLE}Super properties:${RESET}"
    echo -e "  ${PURPLE}Size:${RESET} $SUPER_SIZE bytes"
    echo -e "  ${PURPLE}Metadata size:${RESET} $METADATA_SIZE bytes"
    echo -e "  ${PURPLE}Metadata slots:${RESET} $METADATA_SLOTS"
}

SUPER_PARTITIONS=($(parse_super_partitions "./_images/super/superlpdump.txt"))
extract_super_properties "./_images/super/superlpdump.txt"

# Extract update bin
echo
echo -e "${YELLOW}Extracting update bin${RESET}"
mkdir -p _update_bin
unzip -q "$UPDATE_ZIP" -d _update_bin
echo -e "${GREEN}Update BIN extracted${RESET}"

PARTITIONS=("system" "product" "odm" "system_ext")

echo -e "${CYAN}Starting merge${RESET}"

for partition in "${PARTITIONS[@]}"; do
    img_file="./_images/super/images/${partition}.img"
    transfer_list="./_update_bin/${partition}.transfer.list"
    new_dat="./_update_bin/${partition}.new.dat"
    patch_dat="./_update_bin/${partition}.patch.dat"
    
    if [ -f "$img_file" ] && [ -f "$transfer_list" ] && [ -f "$new_dat" ] && [ -f "$patch_dat" ]; then
    	echo
        echo -e "${YELLOW}Merging ${partition}...${RESET}"
        ./bin/MergeOTA/BlockImageUpdate "$img_file" "$transfer_list" "$new_dat" "$patch_dat" > /dev/null 2>&1
        echo -e "${GREEN}${partition} merge complete!${RESET}"
    else
    	echo
        echo -e "${RED}Skipping ${partition} (doesn't exist)${RESET}"
    fi
done
for partition in "${EXTRAPARTITIONS[@]}"; do
    img_file="./_images/${partition}.img"
    transfer_list="./_update_bin/${partition}.transfer.list"
    new_dat="./_update_bin/${partition}.new.dat"
    patch_dat="./_update_bin/${partition}.patch.dat"
    
    if [ -f "$img_file" ] && [ -f "$transfer_list" ] && [ -f "$new_dat" ] && [ -f "$patch_dat" ]; then
    	echo
        echo -e "${YELLOW}Merging ${partition}...${RESET}"
        ./bin/MergeOTA/BlockImageUpdate "$img_file" "$transfer_list" "$new_dat" "$patch_dat" > /dev/null 2>&1
        echo -e "${GREEN}${partition} merge complete!${RESET}"
    else
    	echo
        echo -e "${RED}Skipping ${partition} (doesn't exist)${RESET}"
    fi
done
rm -rf cache
rm -rf Progress.txt

# Move raw images to out
echo
echo -e "${YELLOW}Moving raw images to out/images${RESET}"
mv _images/super/images out/
echo -e "${GREEN}Done${RESET}"
echo

# Nuke work dirs
echo -e "${YELLOW}Cleaning up work dirs${RESET}"
rm -rf _AP _CSC _images _update_bin _odin_extracted 
echo -e "${GREEN}Cleanup complete.${RESET}"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
HOURS=$((ELAPSED / 3600))
MINS=$(((ELAPSED % 3600) / 60))
SECS=$((ELAPSED % 60))
echo
if [ $HOURS -gt 0 ]; then
    echo "Merge complete in ${HOURS}hr ${MINS}min ${SECS}sec"
elif [ $MINS -gt 0 ]; then
    echo "Merge complete in ${MINS}min ${SECS}sec"
else
    echo "Merge complete in ${SECS}sec, damn that was quick"
fi
