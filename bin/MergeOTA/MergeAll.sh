#!/bin/bash
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
echo "===== Samsung Beta Firmware Merger ====="
echo "Base firmware: $BASE_ZIP"
echo "Update binary: $UPDATE_ZIP"
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
echo "Extracting ODIN firmware ZIP..."
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
echo "Found AP package: $AP_TAR"
echo "Found BL package: $BL_TAR"
echo "Found CP package: $CP_TAR"
echo "Found CSC package: $CSC_TAR"
echo "Found HOME_CSC package: $HOME_TAR"

# Extract optics and prism from csc
echo
echo "Extracting optics.img.lz4 and prism.img.lz4 from CSC..."
mkdir -p _lz4tmp
tar -xf "$CSC_TAR" --no-same-owner -C _lz4tmp optics.img.lz4 prism.img.lz4

# Extract super.img.lz4 from AP
echo
echo "Extracting super.img.lz4 from AP..."
tar -xf "$AP_TAR" --wildcards --no-same-owner -C _lz4tmp 'super.img.lz4'

if [ ! -f _lz4tmp/super.img.lz4 ]; then
    echo "Error: super.img.lz4 not found in AP package!"
    exit 1
fi

# De-LZ4
echo
echo "Decompressing lz4 images..."
mkdir _images
lz4 -d _lz4tmp/optics.img.lz4 _images/optics.img
lz4 -d _lz4tmp/prism.img.lz4 _images/prism.img
lz4 -d _lz4tmp/super.img.lz4 _images/super.img
rm -rf _lz4tmp

# Desparse super
echo
echo "Unsparsing super..."
./bin/MergeOTA/imjtool _images/super.img extract
mv _images/super.img _images/super.img-old 2>/dev/null
mv extracted/image.img _images/super.img
./bin/MergeOTA/imjtool _images/prism.img extract
mv _images/prism.img _images/prism.img-old 2>/dev/null
mv extracted/image.img _images/prism.img
./bin/MergeOTA/imjtool _images/optics.img extract
mv _images/optics.img _images/optics.img-old 2>/dev/null
mv extracted/image.img _images/optics.img
rm -rf extracted

# Extract super
echo
echo "Extracting super"
mkdir _images/super
mkdir _images/super/images
./bin/MergeOTA/lpdump _images/super.img > _images/super/superlpdump.txt
./bin/MergeOTA/lpunpack _images/super.img _images/super/images
echo "Super Extracted"

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
    echo "Extracting super properties..."
    
    # Parse the specific format from your lpdump output
    SUPER_SIZE=$(grep "Size:" "$lpdump_file" | grep "bytes" | awk '{print $(NF-1)}')
    METADATA_SIZE=$(grep "Metadata max size:" "$lpdump_file" | awk '{print $4}')
    METADATA_SLOTS=$(grep "Metadata slot count:" "$lpdump_file" | awk '{print $4}')
    
    echo "Super properties:"
    echo "  Size: $SUPER_SIZE bytes"
    echo "  Metadata size: $METADATA_SIZE bytes"
    echo "  Metadata slots: $METADATA_SLOTS"
}

SUPER_PARTITIONS=($(parse_super_partitions "./_images/super/superlpdump.txt"))
extract_super_properties "./_images/super/superlpdump.txt"

# Extract update bin
echo
echo "Extracting update bin..."
mkdir -p _update_bin
unzip -q "$UPDATE_ZIP" -d _update_bin
echo "Update BIN Extracted."

PARTITIONS=("system" "product" "odm" "system_ext")
EXTRAPARTITIONS=("optics" "prism")

echo "Starting merge..."

for partition in "${PARTITIONS[@]}"; do
    img_file="./_images/super/images/${partition}.img"
    transfer_list="./_update_bin/${partition}.transfer.list"
    new_dat="./_update_bin/${partition}.new.dat"
    patch_dat="./_update_bin/${partition}.patch.dat"
    
    if [ -f "$img_file" ] && [ -f "$transfer_list" ] && [ -f "$new_dat" ] && [ -f "$patch_dat" ]; then
    	echo
        echo "Merging ${partition}..."
        ./bin/MergeOTA/BlockImageUpdate "$img_file" "$transfer_list" "$new_dat" "$patch_dat" > /dev/null 2>&1
        echo "${partition} merge complete!"
    else
    	echo
        echo "Skipping ${partition} (doesn't exist)"
    fi
done
for partition in "${EXTRAPARTITIONS[@]}"; do
    img_file="./_images/${partition}.img"
    transfer_list="./_update_bin/${partition}.transfer.list"
    new_dat="./_update_bin/${partition}.new.dat"
    patch_dat="./_update_bin/${partition}.patch.dat"
    
    if [ -f "$img_file" ] && [ -f "$transfer_list" ] && [ -f "$new_dat" ] && [ -f "$patch_dat" ]; then
    	echo
        echo "Merging ${partition}..."
        ./bin/MergeOTA/BlockImageUpdate "$img_file" "$transfer_list" "$new_dat" "$patch_dat" > /dev/null 2>&1
        echo "${partition} merge complete!"
    else
        echo "Skipping ${partition} (doesn't exist)"
    fi
done
rm -rf cache
rm -rf Progress.txt

# Move raw images to out
echo
echo "Moving raw images to out/images"
mv _images/super/images out/
echo "Done"
echo

# Nuke work dirs
echo "Cleaning up work dirs"
rm -rf _AP _CSC _images _update_bin _odin_extracted 
echo "Cleanup complete."

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
