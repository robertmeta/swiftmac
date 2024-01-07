# swiftmac

## Updates 

### 2024-01-01

This repo has been a bit rebooted and will be adapted to make it easy to keep 
it contributed to the main emacspeak project. 

Bugs can still be reported here. 

## Quickstart

### Build

 - ```make install```

### Setup (recommended settings)

```
  (setq mac-ignore-accessibility 't)
  (setq dtk-program "swiftmac")
  (setenv "SWIFTMAC_TONE_VOLUME" "0.5")
  (setenv "SWIFTMAC_SOUND_VOLUME" "0.5")
  (setenv "SWIFTMAC_VOICE_VOLUME" "1.0")
  (defvar emacspeak-auditory-icon-function #'emacspeak-serve-auditory-icon)
  (require 'emacspeak-setup)
  (dtk-set-rate 250 t)
```

## Having Trouble?

### Double-Speaking

If you are hearing stuff twice, ensure that mac-ignore-accessibility is set 
and your emacs version supports it. If that doesn't work, you can use the 
VoiceOver Utility that comes with MacOS to create an activity for Emacs.app 
to turn off voiceover while in the Emacs window.  This only works if you are
using a windowed version of Emacs (not terminal version). 
