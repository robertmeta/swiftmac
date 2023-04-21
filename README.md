swiftmac
========
This is a drop in replacement for the python "mac" server that comes 
with emacspeak. The goal is to get it mainlined into Emacspeak once
it is feature complete.

You can look at open github issues to see if it is 
missing critical features for your use case.

Quick Install (no prerequisites)
--------------------------------
 - make install-binary or make install-binary-debug 
 - Change the server in your configuration from "mac" to "swiftmac"
 - Restart emacs

Build Your Own
--------------
 - Prerequisite: xcode installed
 - make install or make install-debug
 - Change the server in your configuration from "mac" to "swiftmac"
 - Restart emacs
 
Recommended Settings
----------------------------
```
  (setq dtk-program "swiftmac")
  (setq emacspeak-play-emacspeak-startup-icon nil)
  (setenv "SWIFTMAC_TONE_VOLUME" "0.1")
  (setenv "SWIFTMAC_SOUND_VOLUME" "0.1")
  (setenv "SWIFTMAC_VOICE_VOLUME" "1.0")
  (defvar emacspeak-auditory-icon-function #'emacspeak-serve-auditory-icon)
  (require 'emacspeak-setup)
  (dtk-set-rate 275 t)
```

Motivation
----------
 I wanted a mac experience with a few things that are presently not 
 possible in the mac python server. 
 1. No deps except swift
 2. Compiled and multithread for complete non-blocking operations 
 3. Highly reliable, will never corrupt speech on MacOS
 4. Drop in (no configuration or special setup required in Eamcs or 
    the operating system.
 5. Feature complete support of all emacs speech server commands
 6. With a separate test script to confirm all features work 
 
 Not there yet, but getting close.
