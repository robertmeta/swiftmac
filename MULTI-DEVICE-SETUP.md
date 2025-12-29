# Multi-Device Audio Routing Setup

SwiftMac now supports routing speech and notifications to different physical audio devices!

## How It Works

Emacspeak spawns **two separate swiftmac processes**:
1. **Speech Process**: Handles regular speech output
2. **Notification Process**: Handles notification/auditory icon output

Each process can be configured to use a different audio device and channel.

## Configuration

### In Your Emacs init.el

Add these environment variables BEFORE loading emacspeak:

```elisp
(use-package emacspeak
  :ensure nil
  :init
  (setopt load-path (cons "~/.emacspeak/lisp" load-path))
  (setopt emacspeak-directory "~/.emacspeak")

  ;; Configure multi-device routing
  ;; Speech -> Audioengine D1 (device 125), both channels
  (setenv "SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL" "125:both")

  ;; Notifications -> LG Ultra HD (device 110), left channel only
  (setenv "SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL" "110:left")

  :config
  (setopt dtk-program "swiftmac")

  ;; Enable notification server (spawns second swiftmac process)
  (setopt tts-notification-device "notify")

  (require 'emacspeak-setup))
```

### How Emacspeak Uses These Settings

When `tts-notification-device` is set to a non-default value:

1. **Speech Process** (main):
   - Started normally by Emacspeak
   - Reads `SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL`
   - Outputs to configured speech device

2. **Notification Process**:
   - Spawned by `dtk-notify-initialize`
   - Emacspeak automatically sets `SWIFTMAC_AUDIO_TARGET` to the value of `tts-notification-device`
   - Now also sets `SWIFTMAC_NOTIFICATION_SERVER=1` (triggers notification routing)
   - Reads `SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL`
   - Outputs to configured notification device

## Finding Your Device IDs

Run this command to list available audio devices:

```bash
make list-devices
```

Example output:
```
DeviceID: 110 | "LG Ultra HD" | Channels: 2
Config (both channels): 110:both
Config (left only):     110:left
Config (right only):    110:right

[DEFAULT] DeviceID: 125 | "Audioengine D1" | Channels: 2
Config (both channels): 125:both
Config (left only):     125:left
Config (right only):    125:right
```

## Configuration Format

`SWIFTMAC_*_DEVICE_AND_CHANNEL="<deviceID>:<channel>"`

- **deviceID**: Numeric ID from `make list-devices` (or 0 for system default)
- **channel**: `left`, `right`, or `both`

## Testing

Simple test in Emacs:

```elisp
;; Test speech (should come from speech device)
(dtk-speak "This is speech")

;; Test notification (should come from notification device)
(emacspeak-auditory-icon 'select-object)
```

## Common Configurations

### Separate Devices

```elisp
;; Speech to headphones, notifications to speakers
(setenv "SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL" "125:both")
(setenv "SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL" "89:both")
```

### Same Device, Different Channels

```elisp
;; Both to headphones, but speech in both ears, notifications in left only
(setenv "SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL" "125:both")
(setenv "SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL" "125:left")
```

### Speech Only (No Separate Notifications)

```elisp
;; Don't set tts-notification-device, or set to "default"
(setopt tts-notification-device "default")
```

## Troubleshooting

**Problem**: Both speech and notifications come from same device

- Check that `tts-notification-device` is set to a non-default value (e.g., "notify", "left", or "right")
- Verify environment variables are set BEFORE `(require 'emacspeak-setup)`

**Problem**: No audio at all

- Run `make list-devices` to verify device IDs are correct
- Check device IDs haven't changed (can happen after system updates)
- Try device ID 0 (system default) to test

**Problem**: Emacspeak says "notification mode on" but using wrong device

- The notification server needs `SWIFTMAC_NOTIFICATION_SERVER=1` to be set
- This should be automatic when Emacspeak spawns the notification process
- Check if you're running an updated version of emacspeak/dtk-speak.el
