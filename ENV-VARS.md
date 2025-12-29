# SwiftMac Environment Variables

Complete list of all environment variables recognized by swiftmac.

## Volume Controls

**SWIFTMAC_VOICE_VOLUME**
- Range: 0.0 to 1.0 (1.0 = 100%)
- Default: 1.0
- Controls speech synthesis volume
- Example: `(setenv "SWIFTMAC_VOICE_VOLUME" "0.8")`

**SWIFTMAC_TONE_VOLUME**
- Range: 0.0 to 1.0
- Default: 1.0
- Controls generated tone volume
- Example: `(setenv "SWIFTMAC_TONE_VOLUME" "0.1")`

**SWIFTMAC_SOUND_VOLUME**
- Range: 0.0 to 1.0
- Default: 1.0
- Controls audio file playback volume
- Example: `(setenv "SWIFTMAC_SOUND_VOLUME" "0.1")`

## Device and Channel Routing

**SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL**
- Format: `"<deviceID>:<channel>"`
- deviceID: Numeric device ID from `make list-devices` (0 = system default)
- channel: `left`, `right`, or `both`
- Default: 0:both (system default device, stereo)
- Routes main speech output
- Example: `(setenv "SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL" "125:both")`

**SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL**
- Format: `"<deviceID>:<channel>"`
- Default: 0:left
- Routes notification/auditory icon output
- Example: `(setenv "SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL" "110:left")`

**SWIFTMAC_TONE_DEVICE_AND_CHANNEL**
- Format: `"<deviceID>:<channel>"`
- Default: 0:both
- Routes generated tone output
- Example: `(setenv "SWIFTMAC_TONE_DEVICE_AND_CHANNEL" "125:both")`

**SWIFTMAC_SOUNDEFFECT_DEVICE_AND_CHANNEL**
- Format: `"<deviceID>:<channel>"`
- Default: 0:both
- Routes audio file playback output
- Example: `(setenv "SWIFTMAC_SOUNDEFFECT_DEVICE_AND_CHANNEL" "110:right")`

## Process Mode

**SWIFTMAC_AUDIO_TARGET** (Legacy)
- Values: `"left"`, `"right"`, or `"none"`/`""`
- Default: `""` (none)
- Legacy way to enable notification mode
- When set to "left" or "right", enables buffer-based notification routing
- Still supported for backwards compatibility
- Example: `(setenv "SWIFTMAC_AUDIO_TARGET" "left")`

**SWIFTMAC_NOTIFICATION_SERVER** (New)
- Values: `"1"`, `"true"`, or `"0"`/`""`
- Default: `""` (false)
- Explicitly marks this process as the notification server
- Preferred over SWIFTMAC_AUDIO_TARGET for clarity
- Example: `(setenv "SWIFTMAC_NOTIFICATION_SERVER" "1")`

Note: Either SWIFTMAC_AUDIO_TARGET="left"/"right" OR SWIFTMAC_NOTIFICATION_SERVER="1" will enable notification mode.

## Complete Example

```elisp
;; Volume settings
(setenv "SWIFTMAC_VOICE_VOLUME" "1.0")   ; Full volume for speech
(setenv "SWIFTMAC_TONE_VOLUME" "0.1")    ; Quiet tones
(setenv "SWIFTMAC_SOUND_VOLUME" "0.1")   ; Quiet audio icons

;; Multi-device routing
(setenv "SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL" "125:both")      ; Headphones, stereo
(setenv "SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL" "110:left") ; Monitor, left ear
(setenv "SWIFTMAC_TONE_DEVICE_AND_CHANNEL" "125:both")        ; Headphones
(setenv "SWIFTMAC_SOUNDEFFECT_DEVICE_AND_CHANNEL" "110:left") ; Monitor, left ear

;; These variables are set automatically by Emacspeak, don't set manually:
;; SWIFTMAC_AUDIO_TARGET - Set by Emacspeak when spawning notification process
;; SWIFTMAC_NOTIFICATION_SERVER - Could be set by Emacspeak in future
```

## How Emacspeak Uses These

When `tts-notification-device` is set in Emacspeak, it spawns two swiftmac processes:

1. **Main speech process**:
   - Inherits all SWIFTMAC_* env vars from your init.el
   - Uses `SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL`
   - Uses `SWIFTMAC_TONE_DEVICE_AND_CHANNEL` for tones

2. **Notification process**:
   - Inherits all SWIFTMAC_* env vars from your init.el
   - Emacspeak sets `SWIFTMAC_AUDIO_TARGET` to value of `tts-notification-device`
   - Uses `SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL`
   - Uses `SWIFTMAC_SOUNDEFFECT_DEVICE_AND_CHANNEL` for audio icons

## Finding Device IDs

```bash
make list-devices
```

This shows all available audio output devices with their IDs and channel counts.
