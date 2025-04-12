#!/bin/bash
# ==============================================================================
# Deployment Simulation Script for VPS: hostinger (Phase 1: Hello World)
# ==============================================================================
# This script is intended to be executed on the target VPS associated with hostinger
# by the 'deploy' user, typically triggered by the CD workflow.
# In this phase, it only simulates actions and logs information.
#
# IMPORTANT: Run this script from the directory where it resides.
# The CD workflow should copy files here and then execute:
# ssh deploy@<vps_ip> 'cd /home/deploy/apps/hostinger && bash deploy.sh'
# ==============================================================================

# --- Strict Mode ---
set -euo pipefail

# --- Variables ---
readonly VPS_NAME="hostinger"
# Get the directory where the script itself is located
readonly SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# --- Helper: Log messages ---
log_info() {
    echo "[INFO] [${VPS_NAME}] $1"
}

log_step() {
    echo "-----------------------------------------------------"
    log_info "$1"
    echo "-----------------------------------------------------"
}

# --- Main Execution ---
log_info "Deployment Simulation Started for ${VPS_NAME}"
log_info "Executing User: $(whoami)"
log_info "Script Location: ${SCRIPT_DIR}"
log_info "Current Directory: $(pwd)"
log_info "Timestamp: $(date)"

log_step "Step 1/2: Verifying required files..."
# Check if index.html exists as a basic check
if [[ -f "${SCRIPT_DIR}/index.html" ]]; then
    log_info "Found index.html."
    ls -la "${SCRIPT_DIR}" # List files for context
else
    log_info "WARNING: index.html not found in ${SCRIPT_DIR}!"
fi

log_step "Step 2/2: Simulating service configuration/restart..."
log_info "(No actual services like Docker or Nginx are configured in Phase 1)"
log_info "Hypothetically, commands like 'docker compose up -d' or 'nginx -s reload' would run here."
sleep 1 # Simulate work

log_info "Deployment Simulation Finished Successfully for ${VPS_NAME}!"

exit 0
