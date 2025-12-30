#!/bin/bash

echo "Testing SwiftMac proper dual mode..."

# Kill any existing swiftmac processes
pkill -f swiftmac 2> /dev/null

# Create a fifo for stdin instance
mkfifo /tmp/swiftmac_stdin.fifo 2> /dev/null

# Start the network listener instance on port 2222 (notification mode)
echo "Starting network listener on port 2222 (right ear notification)..."
SWIFTMAC_AUDIO_TARGET=right ./.build/debug/swiftmac -p 2222 &
PID1=$!
echo "Network listener PID: $PID1"

# Start the stdin reader instance (speaker mode - both ears)
echo "Starting stdin reader (speaker mode - both ears)..."
./.build/debug/swiftmac < /tmp/swiftmac_stdin.fifo &
PID2=$!
echo "Stdin reader PID: $PID2"

# Give them time to start
sleep 3

# Check if both are running
if ps -p $PID1 > /dev/null; then
  echo "✓ Network listener (notification) is running"
else
  echo "✗ Network listener crashed"
  exit 1
fi

if ps -p $PID2 > /dev/null; then
  echo "✓ Stdin reader (speaker) is running"
else
  echo "✗ Stdin reader crashed"
  exit 1
fi

# Test sending to both instances
echo "Testing both instances simultaneously..."

# Send to stdin instance
echo "Sending to speaker (both ears)..."
echo "tts_say This is the main speaker going to both ears" > /tmp/swiftmac_stdin.fifo &

# Send to network instance
echo "Sending to notification (right ear)..."
(
  echo "tts_say This is a notification in your right ear"
  sleep 1
) | nc localhost 2222 &

sleep 4

# Check again
echo ""
echo "Final status check:"
if ps -p $PID1 > /dev/null; then
  echo "✓ Network listener still running"
else
  echo "✗ Network listener stopped"
fi

if ps -p $PID2 > /dev/null; then
  echo "✓ Stdin reader still running"
else
  echo "✗ Stdin reader stopped"
fi

# Cleanup
echo ""
echo "Cleaning up..."
echo "tts_exit" > /tmp/swiftmac_stdin.fifo &
(echo "tts_exit") | nc localhost 2222 &
sleep 1

kill $PID1 2> /dev/null
kill $PID2 2> /dev/null
rm -f /tmp/swiftmac_stdin.fifo

echo "Test complete."
