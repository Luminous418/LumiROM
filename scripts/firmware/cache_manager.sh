#!/bin/bash

# Firmware Cache Manager
# Provides utilities to check and manage the firmware image cache

source scripts/utils/bash_colors.sh

CACHE_DIR="./IMGs"
BUILD_PARTITIONS_DEFAULT="product,vendor,odm,system_ext,system"

print_usage() {
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo "${BLUE}   Firmware Cache Manager${RESET}"
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo "Usage: ${GREEN}bash scripts/firmware/cache_manager.sh <command>${RESET}"
    echo ""
    echo "Commands:"
    echo "  ${YELLOW}status${RESET}          - Show cache status and list images"
    echo "  ${YELLOW}check${RESET}           - Verify if all required images exist"
    echo "  ${YELLOW}clear${RESET}           - Clear all cached images"
    echo "  ${YELLOW}size${RESET}            - Show total cache size"
    echo "  ${YELLOW}list${RESET}            - List all image files with sizes"
    echo ""
    echo "Examples:"
    echo "  ${CYAN}bash scripts/firmware/cache_manager.sh status${RESET}"
    echo "  ${CYAN}bash scripts/firmware/cache_manager.sh check${RESET}"
    echo "  ${CYAN}bash scripts/firmware/cache_manager.sh clear${RESET}"
    echo ""
}

status_cache() {
    echo ""
    echo "${BLUE}Cache Directory:${RESET} $CACHE_DIR"
    echo ""
    
    if [ ! -d "$CACHE_DIR" ]; then
        echo "${RED}❌ Cache directory does not exist${RESET}"
        return 1
    fi

    local img_count=$(find "$CACHE_DIR" -maxdepth 1 -name "*.img" -type f 2>/dev/null | wc -l)
    
    if [ $img_count -eq 0 ]; then
        echo "${YELLOW}⚠️  Cache is empty${RESET}"
        return 1
    fi

    echo "${GREEN}✅ Found $img_count image(s)${RESET}"
    echo ""
    echo "${YELLOW}Images:${RESET}"
    
    find "$CACHE_DIR" -maxdepth 1 -name "*.img" -type f 2>/dev/null | while read -r img; do
        local name=$(basename "$img")
        local size=$(du -h "$img" | cut -f1)
        echo "  ${GREEN}✓${RESET} $name (${CYAN}$size${RESET})"
    done
    echo ""
}

check_cache() {
    echo ""
    echo "${BLUE}Checking required partitions...${RESET}"
    echo ""
    
    if [ ! -d "$CACHE_DIR" ]; then
        echo "${RED}❌ Cache directory does not exist${RESET}"
        return 1
    fi

    IFS=',' read -r -a PARTITIONS <<< "$BUILD_PARTITIONS_DEFAULT"
    local missing=0

    for partition in "${PARTITIONS[@]}"; do
        partition=$(echo "$partition" | xargs)
        local img_file="$CACHE_DIR/${partition}.img"
        
        if [ -f "$img_file" ]; then
            local size=$(du -h "$img_file" | cut -f1)
            echo "  ${GREEN}✓${RESET} ${CYAN}$partition.img${RESET} (${GREEN}$size${RESET})"
        else
            echo "  ${RED}✗${RESET} ${CYAN}$partition.img${RESET} (${RED}missing${RESET})"
            missing=$((missing + 1))
        fi
    done

    echo ""
    if [ $missing -eq 0 ]; then
        echo "${GREEN}✅ All required images are cached!${RESET}"
        echo "   ${CYAN}build_local.sh will skip firmware download${RESET}"
        return 0
    else
        echo "${YELLOW}⚠️  $missing image(s) missing${RESET}"
        echo "   ${YELLOW}build_local.sh will download firmware${RESET}"
        return 1
    fi
    echo ""
}

size_cache() {
    echo ""
    
    if [ ! -d "$CACHE_DIR" ]; then
        echo "${RED}❌ Cache directory does not exist${RESET}"
        return 1
    fi

    local total_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    local img_count=$(find "$CACHE_DIR" -maxdepth 1 -name "*.img" -type f 2>/dev/null | wc -l)
    
    if [ $img_count -eq 0 ]; then
        echo "${YELLOW}⚠️  Cache is empty (0 B)${RESET}"
        return 1
    fi

    echo "${BLUE}Cache Statistics:${RESET}"
    echo "  ${CYAN}Total size:${RESET} ${GREEN}$total_size${RESET}"
    echo "  ${CYAN}Image count:${RESET} ${GREEN}$img_count${RESET}"
    echo ""
}

list_cache() {
    echo ""
    
    if [ ! -d "$CACHE_DIR" ]; then
        echo "${RED}❌ Cache directory does not exist${RESET}"
        return 1
    fi

    local img_count=$(find "$CACHE_DIR" -maxdepth 1 -name "*.img" -type f 2>/dev/null | wc -l)
    
    if [ $img_count -eq 0 ]; then
        echo "${YELLOW}⚠️  Cache is empty${RESET}"
        return 1
    fi

    echo "${BLUE}Detailed Image List:${RESET}"
    echo ""
    
    find "$CACHE_DIR" -maxdepth 1 -name "*.img" -type f 2>/dev/null | sort | while read -r img; do
        local name=$(basename "$img")
        local size=$(du -h "$img" | cut -f1)
        local size_bytes=$(stat -f%z "$img" 2>/dev/null || stat -c%s "$img" 2>/dev/null)
        
        printf "  ${GREEN}%-20s${RESET} ${CYAN}%-15s${RESET} (${CYAN}%s bytes${RESET})\n" \
               "$name" "$size" "$size_bytes"
    done
    echo ""
}

clear_cache() {
    echo ""
    echo "${RED}⚠️  WARNING: This will delete all cached firmware images!${RESET}"
    echo "     Path: $CACHE_DIR"
    echo ""
    read -p "Are you sure? (type 'YES' to confirm): " confirm
    
    if [ "$confirm" != "YES" ]; then
        echo "${YELLOW}Cache clear cancelled${RESET}"
        return 1
    fi

    echo ""
    echo "${YELLOW}Clearing cache...${RESET}"
    rm -rf "$CACHE_DIR"
    mkdir -p "$CACHE_DIR"
    echo "${GREEN}✅ Cache cleared successfully${RESET}"
    echo ""
}

# Main logic
if [ $# -eq 0 ]; then
    print_usage
    exit 0
fi

case "$1" in
    status)
        status_cache
        ;;
    check)
        check_cache
        ;;
    size)
        size_cache
        ;;
    list)
        list_cache
        ;;
    clear)
        clear_cache
        ;;
    *)
        echo "${RED}Unknown command: $1${RESET}"
        echo ""
        print_usage
        exit 1
        ;;
esac

exit $?
