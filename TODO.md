# TODO - SwiftMac Audio Routing

## Unimplemented Features

### 1. Multi-Device Routing

**Status:** ✅ WORKING (via environment variables)

**Goal:** Route different audio types to different physical devices (e.g., speech to headphones, notifications to monitor speakers)

**Solution:** Emacspeak's dual-process architecture + device selection in bufferHandler

**How It Works:**
- Emacspeak spawns TWO swiftmac processes (speech + notification)
- Each process configured via environment variables at startup
- `SWIFTMAC_NOTIFICATION_SERVER=1` flag identifies notification process
- bufferHandler selects device based on `isNotificationServer` flag
- All 4 audio types support device/channel routing

**Configuration:**
```elisp
;; In init.el:
(setenv "SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL" "125:both")      ; Speech -> Audioengine D1
(setenv "SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL" "110:left") ; Notifications -> LG Ultra HD
(setenv "SWIFTMAC_TONE_DEVICE_AND_CHANNEL" "125:both")
(setenv "SWIFTMAC_SOUNDEFFECT_DEVICE_AND_CHANNEL" "110:right")
(setopt tts-notification-device "left")  ; Enable notification server
```

**Key Insight:**
The "chipmunk speed" issue was audio DOUBLING - both processes playing simultaneously when we tried separate engines within one process. The dual-process architecture was already the solution!

**See:** MULTI-DEVICE-SETUP.md for full documentation

### Future Enhancement: Runtime Device Switching

**Status:** Planned (not yet working)

**Goal:** Switch audio devices on-the-fly without restarting Emacs

**Runtime Commands (implemented but not functional):**
- `tts_set_speech_device <deviceID>`
- `tts_set_notification_device <deviceID>`
- `tts_set_speech_channel <left|right|both>`
- `tts_set_notification_channel <left|right|both>`

**Issue:** Engine reset/reconnect on device change needs debugging
- Commands execute but device doesn't actually switch
- Likely needs different approach than current engine.reset() + re-attach

**Workaround:** Restart Emacs with different ENV variables to change devices

### 2. Buffer System for Tones and Sound Effects

**Status:** ✅ COMPLETED

**Goal:** Use consistent buffer-based architecture across all four audio types (speech, notifications, tones, sound effects)

**Current State:**
- Speech: Uses AVAudioEngine/AVAudioPlayerNode with buffer-based chunking ✅
- Notifications: Uses same AVAudioEngine system with PCM routing ✅
- Tones: Uses TonePlayerActor with buffer-based playback and own AVAudioEngine ✅
- Sound effects: Uses SoundManager with buffer-based playback and own AVAudioEngine per sound ✅

**Implementation Details:**
- TonePlayerActor: Already had buffer-based architecture, added device/channel routing support
- SoundManager: Converted from AVAudioPlayer to AVAudioEngine + AVAudioPlayerNode
  - Loads audio files into PCM buffers via AVAudioFile
  - Each sound gets its own engine instance for concurrent playback
  - Supports device selection and channel routing (left/right/both)
  - OGG files decoded to WAV first (existing decodeIfNeeded flow)

**Benefits Achieved:**
- Consistent architecture across all audio types
- Unified device/channel routing capabilities for all four streams
- All audio types can now be routed independently

### 3. Issue #48 - Notification Device Variable

**Status:** Original bug report, partially addressed

**Original Issue:** `SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL` environment variable was never fully implemented

**Current State:**
- Environment variable parsing exists in StateStore
- Runtime channel switching works (`tts_set_notification_channel`)
- Device selection blocked by multi-device routing issue (#1 above)

**Needs:** Resolution of multi-device routing to fully implement this feature.

### 4. Runtime Device Switching Commands

**Status:** Not implemented (depends on #1)

**Goal:** Add runtime commands similar to channel switching:
- `tts_set_speech_device <deviceID>`
- `tts_set_notification_device <deviceID>`
- `tts_set_tone_device <deviceID>`
- `tts_set_sound_device <deviceID>`

**Blocked By:** Multi-device routing issue (#1)

## Working Features (For Reference)

These were successfully implemented on the `audio-routing-incremental` branch:

- ✅ Buffer-everywhere architecture for speech and notifications
- ✅ Text chunking (15 words) for single-buffer utterances
- ✅ Aggressive silence trimming for fast response
- ✅ Sequential chunk playback with ChunkQueue
- ✅ PCM channel control (left/right/both)
- ✅ Runtime channel switching commands (`tts_set_speech_channel`, `tts_set_notification_channel`)
- ✅ Buffer flushing on stop (fixes Issue #49)
- ✅ Device enumeration tool (`make list-devices`)
- ✅ Comprehensive documentation

## Notes

The audio-routing work achieved significant improvements even without multi-device support:

1. Fixed buffer flushing during fast navigation (Issue #49)
2. Prevented silence truncation through pre-chunking (Issue #50)
3. Implemented working PCM channel control for accessibility use cases (e.g., notifications in left ear, speech in both)
4. Maintained ultra-low latency for blind user navigation

The multi-device routing remains an interesting technical challenge but is not critical for core functionality.
