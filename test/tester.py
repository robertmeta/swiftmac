import argparse
import os
import select
import subprocess
import sys
import time

script_dir = os.path.dirname(os.path.abspath(__file__))


def run_program(program, script):
    env = {}
    process = None
    skip = False

    for line in script:
        line = line.strip()
        line = line.replace("$SD", script_dir)

        if line.startswith("END_SKIP"):
            print("Skip Mode OFF")
            skip = False
            continue
        if line.startswith("#") or line == "" or skip == True:
            # print(f"S: {line}")
            continue
        if line.startswith("START_SKIP"):
            print("Skip Mode On")
            skip = True
            continue
        if line.startswith("ENV "):
            parts = line.split(" ", 2)
            if len(parts) == 3:
                key, value = parts[1], parts[2]
                env[key] = value
        elif line == "ENVCLEAR":
            env.clear()
        elif line == "RESTART":
            if process:
                process.stdin.close()
                process.stdout.close()
                process.stderr.close()
                process.wait()
            process = subprocess.Popen(
                program,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
            )
        elif line.startswith("DELAY "):
            delay = float(line.split(" ", 1)[1])
            print(f"D: {delay}")
            time.sleep(delay)
        else:
            if process:
                print(f"> {line}")
                process.stdin.write(line + "\n")
                process.stdin.flush()

                timeout = 0.1  # Adjust the timeout as needed
                while True:
                    ready, _, _ = select.select([process.stdout], [], [], timeout)
                    if ready:
                        output = process.stdout.readline()
                        if output == "":
                            break
                        print(f"< {output.strip()}")
                    else:
                        break

                    if process.poll() is not None:
                        break

    if process:
        process.stdin.close()
        process.stdout.close()
        process.stderr.close()


def main():
    parser = argparse.ArgumentParser(
        description="Run a program and send stdin data with a delay."
    )
    parser.add_argument("-p", "--program", required=True, help="The program to run")
    parser.add_argument(
        "-s",
        "--script",
        type=argparse.FileType("r"),
        default=sys.stdin,
        help="The script file to read from (default: stdin)",
    )

    args = parser.parse_args()

    run_program(args.program, args.script)


if __name__ == "__main__":
    main()
