import subprocess
import sys
import time

# Check if the correct number of arguments was passed
if len(sys.argv) != 2:
    print("Usage: python3 test-server.py <server>")
    sys.exit(1)

# Get the file name from the command-line argument
server = sys.argv[1]

# Define the command to run as a list of strings
command = [server]

# Open a subprocess and pipe data to its stdin
with subprocess.Popen(command, stdin=subprocess.PIPE) as process:
    process.stdin.write(b"tts_say a b c d e f g h i j k l m n o p q r s t u v w x y z\n")
    process.stdin.flush()
    time.sleep(3)
