#!/bin/bash

# --- LumiROM Logging System ---
# This script provides centralized logging functions for build_local.sh
# All logs are saved to the LOGS directory with timestamps

# --- Logging Configuration ---
export LOGS_DIR="${LOGS_DIR:-$PWD/LOGS}"
export LOG_TIMESTAMP="${LOG_TIMESTAMP:-$(date +%Y-%m-%d_%H-%M-%S)}"
export LOG_FILE="$LOGS_DIR/${LOG_TIMESTAMP}_build.log"
export ERROR_LOG="$LOGS_DIR/${LOG_TIMESTAMP}_errors.log"
export SUMMARY_LOG="$LOGS_DIR/${LOG_TIMESTAMP}_summary.log"

# Ensure LOGS directory exists
mkdir -p "$LOGS_DIR"

# --- Logging Functions ---

# log_message: Print message with timestamp to console and log file
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# log_error: Print error message to console, log file, and error log
log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $message" | tee -a "$LOG_FILE" "$ERROR_LOG"
}

# log_section: Print section header with dividers
log_section() {
    local section="$1"
    log_message "${BLUE}=========================================${RESET}"
    log_message "${HI_BLUE}$section${RESET}"
    log_message "${BLUE}=========================================${RESET}"
}

# initialize_logs: Create header for the log file
initialize_logs() {
    local stock_device="$1"
    local target_device="$2"
    local target_csc="$3"
    local target_imei="$4"
    local lumirom_version="$5"
    local use_mods="$6"
    local use_galaxy_ai="$7"
    local use_ui_8_tethering_apex="$8"
    local output_filesystem="$9"
    
    {
        echo "${BLUE}======================================${RESET}"
        echo "${HI_BLUE}LumiROM Build Log${RESET}"
        echo "${BLUE}======================================${RESET}"
        echo "Start Time: $(date)"
        echo "Stock Device: $stock_device"
        echo "Target Device: $target_device"
        echo "Target CSC: $target_csc"
        echo "Target IMEI: $target_imei"
        echo "Version: $lumirom_version"
        echo "Use Mods: $use_mods"
        echo "Use Galaxy AI: $use_galaxy_ai"
        echo "Use UI 8 Tethering Apex: $use_ui_8_tethering_apex"
        echo "Output Filesystem: $output_filesystem"
        echo "${BLUE}======================================${RESET}"
        echo
    } > "$LOG_FILE"
    
    {
        echo "${BLUE}======================================${RESET}"
        echo "${HI_BLUE}LumiROM Build Log${RESET}"
        echo "${BLUE}======================================${RESET}"
        echo "Start Time: $(date)"
        echo "Stock Device: $stock_device"
        echo "Target Device: $target_device"
        echo "Target CSC: $target_csc"
        echo "Target IMEI: $target_imei"
        echo "Version: $lumirom_version"
        echo "Use Mods: $use_mods"
        echo "Use Galaxy AI: $use_galaxy_ai"
        echo "Use UI 8 Tethering Apex: $use_ui_8_tethering_apex"
        echo "Output Filesystem: $output_filesystem"
        echo "${BLUE}======================================${RESET}"
        echo
    } > "$LOG_FILE"
}

# finalize_logs: Create final summary log with build duration and status
finalize_logs() {
    local start_time="$1"
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local hours=$((elapsed / 3600))
    local mins=$(((elapsed % 3600) / 60))
    local secs=$((elapsed % 60))
    
    # Format time string
    if [ $hours -gt 0 ]; then
        local time_str="${hours}hr ${mins}min ${secs}sec"
    elif [ $mins -gt 0 ]; then
        local time_str="${mins}min ${secs}sec"
    else
        local time_str="${secs}sec (damn that was quick!)"
    fi
    
    log_message "Build completed in $time_str"
    
    # Create summary log
    {
        echo "${BLUE}======================================${RESET}"
        echo "${HI_BLUE}LumiROM Build Summary${RESET}"
        echo "${BLUE}======================================${RESET}"
        echo "Build started: $(date -d @$start_time)"
        echo "Build ended:   $(date -d @$end_time)"
        echo "Build duration: $time_str"
        echo
        if [ -s "$ERROR_LOG" ]; then
            echo "Errors encountered:"
            cat "$ERROR_LOG"
        else
            echo "✓ Build completed successfully with no errors"
        fi
        echo "${BLUE}======================================${RESET}"
    } | tee -a "$SUMMARY_LOG"
    
    log_section "Process completed - See logs in $LOGS_DIR"
}
