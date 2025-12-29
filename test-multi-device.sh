#!/bin/bash

# Test multi-device audio routing with new SWIFTMAC_NOTIFICATION_SERVER flag

# Configuration:
# - Speech: Device 125 (Audioengine D1) - both channels
# - Notifications: Device 110 (LG Ultra HD) - left channel only

export SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL="125:both"
export SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL="110:left"
export SWIFTMAC_NOTIFICATION_SERVER="1"  # NEW FLAG!

echo "Testing multi-device routing:"
echo "  Speech -> Device 125 (Audioengine D1), both channels"
echo "  Notifications -> Device 110 (LG Ultra HD), left channel"
echo ""
echo "Launching Emacs..."

# Launch Emacs
em
