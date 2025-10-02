# Swift Concurrency Fixes and Modernizations

## Critical Race Conditions Fixed

### 1. ConnectionBufferManager Actor (main.swift:28-60)
**Problem**: Global mutable `connectionBuffers` dictionary accessed from multiple network connections without synchronization.

**Fix**: Created `ConnectionBufferManager` actor with proper isolation:
- Moved buffer management into actor-isolated methods
- `extractLines()` and `clear()` now properly synchronized
- Network callbacks use `Task {}` to await actor calls

### 2. AVAudioEngine Setup Race (main.swift:89-127)
**Problem**: Multiple buffers arriving simultaneously could execute setup block concurrently, causing duplicate engine connections.

**Fix**: Added `NSLock` for thread-safe setup:
- Check-then-act pattern now properly locked
- Early unlock before buffer scheduling to avoid holding lock during playback
- Prevents crashes from concurrent engine.connect() calls

### 3. AVSpeechSynthesizer Thread Safety (main.swift:22-28)
**Problem**: `AVSpeechSynthesizer` is not thread-safe but was accessed from multiple async contexts.

**Fix**: Created `@MainActor` isolated `SpeakerManager`:
- All speech synthesis operations now run on MainActor
- Functions marked with `@MainActor`: `instantStopSpeaking`, `instantTtsPause`, `instantTtsResume`, `doSpeak`, `_doSpeak`
- Singleton pattern ensures single instance

### 4. StateStore Reset (main.swift:374-379)
**Problem**: `instantTtsReset()` was replacing global actor instance, causing other tasks to use stale state.

**Fix**: Use existing `reset()` method instead:
- Calls `await ss.reset()` to reset state in-place
- Other tasks continue using same actor instance with reset state

## Performance Optimizations

### 5. Batch Actor Reads (statestore.swift:303-324)
**Enhancement**: Extended `getSpeechSettings()` to include `audioTarget`:
- Reduced actor hops in `_doSpeak()` from 2 to 1
- Eliminated separate `notificationMode()` call
- Inline check: `settings.audioTarget == "right" || settings.audioTarget == "left"`

### 6. Removed Unnecessary async (main.swift)
**Modernization**: Functions that don't need async removed from async context:
- `splitOnSquareStar()`: Pure string manipulation
- `isolateCommand()`: Pure string parsing
- `isolateCmdAndParams()`: Pure string parsing
- `splitStringAtSpaceBeforeCapitalLetter()`: Pure regex operations

### 7. Eliminated Unstructured Tasks
**Fix**: Direct async calls instead of wrapping in `Task {}`:
- `doTone()`: Now directly awaits `tonePlayer.playPureTone()`
- `doPlaySound()`: Now directly awaits `SoundManager.shared.playSound()`

## Code Modernizations

### 8. Logger File Handle Recovery (logger.swift:44-64)
**Enhancement**: Auto-recreate log file if deleted:
- Checks if `fileHandle` is nil before each write
- Attempts to reopen existing file
- Creates new file if missing
- Ensures logging continues even if file deleted

### 9. StateStore nextPreDelay (statestore.swift:133-142)
**Enhancement**: Added explicit `consumeNextPreDelay()` method:
- Separates read from reset behavior
- `getSpeechSettings()` uses this to atomically consume and reset
- Prevents potential reentrancy issues

### 10. Improved Guard Patterns (main.swift)
**Modernization**:
- `isFirstLetterCapital()`: Changed from force unwrap to guard-let
- `isolateCommand()`: Simplified substring extraction using String slice
- `isolateCmdAndParams()`: Replaced manual brace removal with `dropFirst().dropLast()`

### 11. CommandLineChannel Sendable (main.swift:62)
**Modernization**: Marked `CommandLineChannel` as `Sendable`:
- Makes it safe to share across concurrency domains
- AsyncStream.Continuation is already thread-safe

### 12. TonePlayerActor Cleanup (toneplayer.swift:71-75)
**Modernization**: Removed redundant weak self capture in outer closure:
- Inner Task already captures weak self
- Outer closure doesn't need weak capture

## Build Status

✅ All changes compile successfully
✅ No new warnings introduced
✅ Thread safety verified with actor isolation
✅ MainActor isolation enforces UI thread requirements

## Testing Recommendations

1. **Concurrency Testing**: Run with dozens of commands per second to verify no crashes
2. **Network Mode**: Test multiple simultaneous connections
3. **Notification Mode**: Verify audio routing still works correctly
4. **Log File**: Delete log file during operation to test recovery
5. **State Reset**: Test `tts_reset` command doesn't cause state corruption
