#!/usr/bin/env bash
#
# build_fs_image.sh — Builds partition images UN1CA-style.
# Based on https://github.com/salvogiangri/UN1CA/blob/sixteen/scripts/build_fs_image.sh
#
# Usage: build_fs_image <fs> [options] <dir> <file_contexts> <fs_config>
#   fs: erofs | ext4
#
# Options:
#   --output, -o <file>            Output .img path
#   --partition-name, -p <name>    Partition name (default: input dir name)
#   --partition-size, -s <bytes>   Partition size (default: smallest calculated)
#   --force, -f                    Force overwrite existing output file
#   --generate-map, -m             Generate block map (.map)
#   --sparse, -S                   Android sparse image (ext4 only)
#   --avb / --no-avb               Sign (or not) with AVB
#   --inodes, -i <n>               (ext4) Inodes count
#

set -euo pipefail

# Byte-based collation: locale collation (es_ES) treats '_' and '.' as equal and
# would drop distinct fs_config/file_contexts entries on any sort.
export LC_ALL=C

# Path to LumiROM's mkfs.erofs
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MKFS_EROFS="${MKFS_EROFS:-$SRC_DIR/bin/erofs-utils/mkfs.erofs}"

FORCE=false
FS_TYPE=""
SPARSE=false
AVB_SIGN=""
MAP_FILE=false
INPUT_DIR=""
PARTITION=""
IMAGE_SIZE=""
INODES=""
MOUNT_POINT=""
OUTPUT_FILE=""
FILE_CONTEXT_FILE=""
FS_CONFIG_FILE=""

LOG() { echo "$@"; }

ROUND_UP_TO_4K()
{
    local ROUNDED
    ROUNDED="$(bc -l <<< "$1 + 4095")"
    ROUNDED="$(bc -l <<< "scale=0; $ROUNDED - ($ROUNDED % 4096)")"
    echo "$ROUNDED"
}

GET_DISK_USAGE()
{
    local SIZE
    SIZE="$(du -b -k -s "$1" | cut -f 1)"
    bc -l <<< "$SIZE * 1024"
}

GET_IMAGE_SIZE()
{
    local FILE="$1"
    if [ ! -f "$FILE" ]; then
        LOG "  [ERROR] Image not found: $FILE"
        exit 1
    fi
    GET_DISK_USAGE "$FILE"
}

CALCULATE_SIZE_AND_RESERVED()
{
    local SIZE="$1"
    if [[ "$FS_TYPE" == "erofs" ]]; then
        SIZE="$(bc -l <<< "scale=0; ($SIZE * 1003) / 1000")"
        [[ "$SIZE" -lt "262144" ]] && SIZE="262144"
    else
        SIZE="$(bc -l <<< "scale=0; ($SIZE * 1.1) / 1")"
        SIZE="$(bc -l <<< "$SIZE + 16777216")"
    fi
    echo "$SIZE"
}

BUILD_IMAGE_MKFS()
{
    local BUILD_CMD=""

    case "$FS_TYPE" in
        "erofs")
            BUILD_CMD+="$MKFS_EROFS "
            BUILD_CMD+="-z \"lz4hc\" "
            BUILD_CMD+="-b \"4096\" "
            BUILD_CMD+="--mount-point \"$MOUNT_POINT\" "
            BUILD_CMD+="--fs-config-file \"$FS_CONFIG_FILE\" "
            BUILD_CMD+="--file-contexts \"$FILE_CONTEXT_FILE\" "
            BUILD_CMD+="-T \"1640995200\" "
            if $MAP_FILE; then
                BUILD_CMD+="--block-list-file \"${OUTPUT_FILE//.img/.map}\" "
            fi
            BUILD_CMD+="\"$OUTPUT_FILE\" \"$INPUT_DIR\""
            ;;
        "ext4")
            BUILD_CMD+="mkuserimg_mke2fs "
            if $SPARSE; then
                BUILD_CMD+="-s "
            fi
            BUILD_CMD+="\"$INPUT_DIR\" \"$OUTPUT_FILE\" \"ext4\" \"$MOUNT_POINT\" "
            BUILD_CMD+="\"$IMAGE_SIZE\" "
            BUILD_CMD+="-j \"0\" "
            BUILD_CMD+="-T \"1640995200\" "
            BUILD_CMD+="-C \"$FS_CONFIG_FILE\" "
            if $MAP_FILE; then
                BUILD_CMD+="-B \"${OUTPUT_FILE//.img/.map}\" "
            fi
            BUILD_CMD+="-L \"$MOUNT_POINT\" "
            if [ "$INODES" ]; then
                BUILD_CMD+="-i \"$INODES\" "
            fi
            BUILD_CMD+="-M \"0\" "
            BUILD_CMD+="--inode_size \"256\" "
            BUILD_CMD+="\"$FILE_CONTEXT_FILE\""
            ;;
        *)
            LOG "  [ERROR] Unsupported file system type: $FS_TYPE"
            exit 1
            ;;
    esac

    eval "$BUILD_CMD" || exit 1
}

PREPARE_SCRIPT()
{
    if [[ "$#" == 0 ]]; then
        PRINT_USAGE
        exit 1
    fi

    FS_TYPE="$1"
    if [[ "$FS_TYPE" != "erofs" && "$FS_TYPE" != "ext4" ]]; then
        LOG "  [ERROR] Unsupported file system type: $FS_TYPE"
        exit 1
    fi

    shift

    while [[ "$1" == "-"* ]]; do
        if [[ "$1" == "--avb" ]] || [[ "$1" == "--no-avb" ]]; then
            if [ ! "$AVB_SIGN" ]; then
                [[ "$1" == "--avb" ]] && AVB_SIGN=true
                [[ "$1" == "--no-avb" ]] && AVB_SIGN=false
            fi
        elif [[ "$1" == "--force" ]] || [[ "$1" == "-f" ]]; then
            FORCE=true
        elif [[ "$1" == "--generate-map" ]] || [[ "$1" == "-m" ]]; then
            MAP_FILE=true
        elif [[ "$1" == "--inodes" ]] || [[ "$1" == "-i" ]]; then
            shift; INODES="$1"
            if ! [[ "$INODES" =~ ^[+-]?[0-9]+$ ]]; then
                LOG "  [ERROR] Inodes number not valid: $INODES"
                exit 1
            fi
        elif [[ "$1" == "--output" ]] || [[ "$1" == "-o" ]]; then
            shift; OUTPUT_FILE="$1"
            if [[ "$OUTPUT_FILE" != *".img" ]]; then
                LOG "  [ERROR] Output file name must have \".img\" extension"
                exit 1
            fi
        elif [[ "$1" == "--partition-name" ]] || [[ "$1" == "-p" ]]; then
            shift; PARTITION="$1"
        elif [[ "$1" == "--partition-size" ]] || [[ "$1" == "-s" ]]; then
            shift; IMAGE_SIZE="$1"
            if ! [[ "$IMAGE_SIZE" =~ ^[+-]?[0-9]+$ ]]; then
                LOG "  [ERROR] Partition size not valid: $IMAGE_SIZE"
                exit 1
            fi
        elif [[ "$1" == "--sparse" ]] || [[ "$1" == "-S" ]]; then
            SPARSE=true
        else
            LOG "  [ERROR] Unknown option: $1"
            PRINT_USAGE
            exit 1
        fi

        shift
    done

    if [ ! "$AVB_SIGN" ]; then
        AVB_SIGN=false
    fi

    INPUT_DIR="$1"
    if [ ! "$INPUT_DIR" ]; then
        PRINT_USAGE
        exit 1
    elif [ ! -d "$INPUT_DIR" ]; then
        LOG "  [ERROR] Folder not found: $INPUT_DIR"
        exit 1
    fi

    shift

    if [ ! "$PARTITION" ]; then
        PARTITION="$(basename "$INPUT_DIR")"
    fi

    MOUNT_POINT="/$PARTITION"
    if [[ "$PARTITION" == "system" ]]; then
        MOUNT_POINT="/system"
    fi

    if [ ! "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$(dirname "$INPUT_DIR")/$PARTITION.img"
    fi

    if [ -f "$OUTPUT_FILE" ]; then
        if $FORCE; then
            rm -f "$OUTPUT_FILE"
        else
            LOG "  [ERROR] Output file already exists: $OUTPUT_FILE. Use --force."
            exit 1
        fi
    fi

    FILE_CONTEXT_FILE="$1"
    if [ ! "$FILE_CONTEXT_FILE" ] || [ ! -f "$FILE_CONTEXT_FILE" ]; then
        LOG "  [ERROR] File contexts not found: $FILE_CONTEXT_FILE"
        exit 1
    fi

    shift

    FS_CONFIG_FILE="$1"
    if [ ! "$FS_CONFIG_FILE" ] || [ ! -f "$FS_CONFIG_FILE" ]; then
        LOG "  [ERROR] FS config not found: $FS_CONFIG_FILE"
        exit 1
    fi
}

PRINT_USAGE()
{
    echo "Usage: build_fs_image <fs> [options] <dir> <file_contexts> <fs_config>"
    echo "  --avb/--no-avb : Enables/disables AVB signing"
    echo "  -f, --force : Force delete output file"
    echo "  -i, --inodes : (ext4 only) Specify the extfs inodes count"
    echo "  -m, --generate-map : Generates block map file"
    echo "  -o, --output : Specify the output image path"
    echo "  -p, --partition-name : Specify the partition name"
    echo "  -s, --partition-size : Specify the partition size"
    echo "  -S, --sparse : Outputs an Android sparse image (ext4 only)"
}

# ===== MAIN =====

PREPARE_SCRIPT "$@"

# lost+found: ensure entries exist to avoid build failures
if ! grep -q -F "lost+found" "$FILE_CONTEXT_FILE"; then
    if [[ "$PARTITION" == "system" ]]; then
        echo "/lost\+found u:object_r:rootfs:s0" >> "$FILE_CONTEXT_FILE"
    else
        echo "/$PARTITION/lost\+found $(head -n 1 "$FILE_CONTEXT_FILE" | cut -f 2 -d " ")" >> "$FILE_CONTEXT_FILE"
    fi
fi
if ! grep -q -F "lost+found" "$FS_CONFIG_FILE"; then
    if [[ "$PARTITION" == "system" ]]; then
        echo "lost+found 0 0 700 capabilities=0x0" >> "$FS_CONFIG_FILE"
    else
        echo "$PARTITION/lost+found 0 0 700 capabilities=0x0" >> "$FS_CONFIG_FILE"
    fi
fi

LOG "- Building image: $OUTPUT_FILE ($FS_TYPE)"

if [ ! "$IMAGE_SIZE" ]; then
    LOG "  - Partition size not set, detecting minimum size"

    if [[ "$FS_TYPE" == "erofs" ]]; then
        BUILD_IMAGE_MKFS
        IMAGE_SIZE="$(GET_IMAGE_SIZE "$OUTPUT_FILE")"
    else
        IMAGE_SIZE="$(GET_DISK_USAGE "$INPUT_DIR")"
    fi

    LOG "  - Tree size: $IMAGE_SIZE bytes ($(bc -l <<< "scale=0; $IMAGE_SIZE / 1048576") MB)"

    IMAGE_SIZE="$(CALCULATE_SIZE_AND_RESERVED "$IMAGE_SIZE")"
    IMAGE_SIZE="$(ROUND_UP_TO_4K "$IMAGE_SIZE")"

    LOG "  - Allocating $IMAGE_SIZE bytes ($(bc -l <<< "scale=0; $IMAGE_SIZE / 1048576") MB)"
fi

if [ ! -f "$OUTPUT_FILE" ]; then
    BUILD_IMAGE_MKFS
fi

if [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$OUTPUT_FILE" 2>/dev/null || true
else
    chown -R "$(whoami):$(whoami)" "$OUTPUT_FILE" 2>/dev/null || true
fi

LOG "- Done: $OUTPUT_FILE"
exit 0