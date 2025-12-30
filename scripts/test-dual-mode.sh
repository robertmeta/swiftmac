#!/bin/bash

echo "Testing SwiftMac dual mode (stdin + network)..."

# Kill any existing swiftmac processes
pkill -f swiftmac 2> /dev/null

# Start the network listener instance on port 2222 (notification mode)
echo "Starting network listener on port 2222 (notification mode)..."
SWIFTMAC_AUDIO_TARGET=right ./.build/debug/swiftmac -p 2222 &
PID1=$!
echo "Network listener PID: $PID1"

# Give it time to start
sleep 2

# Start the stdin reader instance (speaker mode)
echo "Starting stdin reader (speaker mode)..."
./.build/debug/swiftmac < /dev/null &
PID2=$!
echo "Stdin reader PID: $PID2"

sleep 2

# Check if both are running
if ps -p $PID1 > /dev/null; then
  echo "✓ Network listener is running"
else
  echo "✗ Network listener crashed"
fi

if ps -p $PID2 > /dev/null; then
  echo "✓ Stdin reader is running"
else
  echo "✗ Stdin reader crashed"
fi

# Test sending to network instance
echo "Testing network instance..."
(
  echo "tts_say Hello from network instance"
  sleep 1
  echo "tts_exit"
) | nc localhost 2222 &

sleep 3

# Check again
echo "Final status check:"
if ps -p $PID1 > /dev/null; then
  echo "✓ Network listener still running"
else
  echo "✗ Network listener stopped"
fi

# Cleanup
kill $PID1 2> /dev/null
kill $PID2 2> /dev/null

echo "Test complete."
