#!/bin/bash

# Test script to verify multiple instances can run simultaneously

echo "Testing multiple SwiftMac instances..."

# Create test fifos for each instance
mkfifo /tmp/swiftmac_test1.fifo 2> /dev/null
mkfifo /tmp/swiftmac_test2.fifo 2> /dev/null

# Start first instance (speaker mode - both ears)
echo "Starting instance 1 (speaker mode)..."
./.build/debug/swiftmac < /tmp/swiftmac_test1.fifo > /tmp/swiftmac1.log 2>&1 &
PID1=$!
echo "Instance 1 PID: $PID1"

# Start second instance (notification mode - right ear)
echo "Starting instance 2 (notification mode - right ear)..."
SWIFTMAC_AUDIO_TARGET=right ./.build/debug/swiftmac < /tmp/swiftmac_test2.fifo > /tmp/swiftmac2.log 2>&1 &
PID2=$!
echo "Instance 2 PID: $PID2"

# Give them time to start
sleep 2

# Test first instance
echo "Testing instance 1..."
echo "tts_say Hello from instance one" > /tmp/swiftmac_test1.fifo &
sleep 2

# Test second instance
echo "Testing instance 2..."
echo "tts_say Hello from instance two" > /tmp/swiftmac_test2.fifo &
sleep 2

# Send different commands to each
echo "Sending concurrent commands..."
echo "tts_say This is the first speaker instance" > /tmp/swiftmac_test1.fifo &
echo "tts_say This is the second notification instance" > /tmp/swiftmac_test2.fifo &
sleep 3

# Check if both are still running
if ps -p $PID1 > /dev/null; then
  echo "✓ Instance 1 is still running"
else
  echo "✗ Instance 1 crashed"
fi

if ps -p $PID2 > /dev/null; then
  echo "✓ Instance 2 is still running"
else
  echo "✗ Instance 2 crashed"
fi

# Cleanup
echo "Cleaning up..."
echo "tts_exit" > /tmp/swiftmac_test1.fifo &
echo "tts_exit" > /tmp/swiftmac_test2.fifo &
sleep 1

kill $PID1 2> /dev/null
kill $PID2 2> /dev/null
rm -f /tmp/swiftmac_test1.fifo /tmp/swiftmac_test2.fifo

echo "Test complete. Check /tmp/swiftmac1.log and /tmp/swiftmac2.log for details."
