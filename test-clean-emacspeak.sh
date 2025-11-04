#!/bin/bash

# Test script to run Emacspeak with swiftmac in a clean environment
# This bypasses all user configuration to test just Emacspeak + swiftmac
# Note: This script is deprecated. Use 'make test-emacs' instead.

set -e

# Get the absolute path to this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set environment variables for Emacspeak
export EMACSPEAK_DIR="${HOME}/.emacspeak"
export DTK_PROGRAM="${SCRIPT_DIR}/.build/debug/swiftmac"

# Only build if binary doesn't exist
if [ ! -f "${DTK_PROGRAM}" ]; then
  echo "Building swiftmac..."
  cd "${SCRIPT_DIR}"
  make debug
fi

echo ""
echo "Testing with local build: ${DTK_PROGRAM}"
echo "Starting clean Emacs with only Emacspeak + swiftmac..."
echo "This will use -Q to bypass all your personal configuration."
echo ""
echo "TIP: Use 'make test-emacs' for a smarter build"
echo ""

# Launch Emacs with:
# -Q: Skip all user configuration (init.el, early-init.el, etc.)
# -l: Load minimal emacspeak configuration
emacs -Q -l "${SCRIPT_DIR}/minimal-emacspeak-init.el"
