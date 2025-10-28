# Repository Guidelines

## Project Structure & Module Organization
The Swift package code lives in `Sources/SwiftMacPackage`, with `main.swift` orchestrating audio routing and helpers split across `logger.swift`, `statestore.swift`, `soundmanager.swift`, and `toneplayer.swift`. Build outputs land in `.build/` and are consumed by integration scripts (`test-*.sh`) and Emacspeak deployment helpers (`cloud-swiftmac`, `log-swiftmac`). The root `Makefile` mirrors the Emacspeak layout, so keep supporting assets (`swiftmac-voices.el`, `show-voices.swift`) alongside the Swift sources unless you are intentionally refactoring distribution tooling.

## Build, Test, and Development Commands
Run `swift build` for a debug binary or `swift build -c release` for production bits; both respect SwiftPM configuration in `Package.swift`. `make debug` and `make release` wrap those commands and clean first, while `make install` and `make install-debug` copy binaries into the Emacspeak tree specified by `EMACSPEAK_DIR`. `swift run swiftmac -p 2222` starts the TCP listener in notification mode; omit the flag to consume stdin. Use `make tidy` to apply `swift-format` across package sources before sharing changes.

## Coding Style & Naming Conventions
Swift files follow two-space indentation with trailing commas avoided. Prefer lowerCamelCase for variables/functions, UpperCamelCase for types, and uppercase snake case only for environment keys. Maintain the existing logging pattern that funnels through `Logger` and keep public surface signatures async-safe when interacting with actors. Format code via `swift-format` (invoked manually or through `make tidy`) before committing.

## Testing Guidelines
Automated tests are currently shell-driven integration checks. After compiling the debug target, run `./test-proper-dual.sh` to exercise simultaneous stdin and network playback, and `./test-dual-mode.sh` or `./test-multiple-instances.sh` for focused scenarios. These scripts expect `.build/debug/swiftmac` and may leave FIFOs in `/tmp`, so clean up if they abort early. Add new tests as shell scripts or SwiftPM test targets placed under `Tests/` once introduced, following the `test-<feature>.sh` naming pattern.

## Commit & Pull Request Guidelines
Match the repository’s history by using short, imperative commit subjects ending with a colon (e.g., `Fix notify crash:`). Squash fixup commits before opening a PR, describe behavioral changes and testing evidence, and link relevant issues or Emacspeak discussion notes. Include screenshots or terminal transcripts when altering audio routing, listener behavior, or installer tooling so reviewers can validate outputs without reproducing locally.

## Configuration & Deployment Notes
Most deployment targets require `EMACSPEAK_DIR` to point at a writable Emacspeak checkout. Use `SWIFTMAC_AUDIO_TARGET=left|right` when running the binary to force channel routing, mirroring how the integration scripts exercise notification mode. Avoid committing generated `.build/` artifacts, downloaded releases, or Emacspeak copies—those belong to local deployment directories only.
