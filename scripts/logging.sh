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
    log_message "========================================="
    log_message "$section"
    log_message "========================================="
}

# initialize_logs: Create header for the log file
initialize_logs() {
    local stock_device="$1"
    local lumirom_version="$2"
    local output_filesystem="$3"
    local use_mods="$4"
    local use_galaxy_ai="$5"
    
    {
        echo "======================================"
        echo "LumiROM Build Log"
        echo "======================================"
        echo "Start Time: $(date)"
        echo "Device: $stock_device"
        echo "Version: $lumirom_version"
        echo "Output Filesystem: $output_filesystem"
        echo "Use Mods: $use_mods"
        echo "Use Galaxy AI: $use_galaxy_ai"
        echo "======================================"
        echo
    } > "$LOG_FILE"
}

# finalize_logs: Create final summary log with build duration and status
finalize_logs() {
    local stock_device="$1"
    local lumirom_version="$2"
    local output_filesystem="$3"
    local use_mods="$4"
    local use_galaxy_ai="$5"
    local start_time="$6"
    
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
        echo "======================================"
        echo "LumiROM Build Summary"
        echo "======================================"
        echo "Device: $stock_device"
        echo "Version: $lumirom_version"
        echo "Output Filesystem: $output_filesystem"
        echo "Use Mods: $use_mods"
        echo "Use Galaxy AI: $use_galaxy_ai"
        echo
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
        echo "======================================"
    } | tee -a "$SUMMARY_LOG"
    
    log_section "Process completed - See logs in $LOGS_DIR"
}
