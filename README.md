swiftmac
========

TODO
-----------
1. Find the heavy use bug in the tone generation code, it seems to only happen 
rarely when doing stuff like riding the backspace key to delete a lot of text. 
2. Fix behavior of stop to NOT stop audio-icons. 
3. Fix "overloaded" delay, when massive amounts of text or events are sent to
the server it will lag hard sometimes, eventually it will recover, but ugly. 
4. Currently, I treat a and p the same, when a should be queued and p instantly
played.
5. Beepcaps currently are not support, but the route to support them is custom
callback injection, totally doable, just need to do it. 
6. Setup the error handling delegate for logging.
7. Fix lag when queueing lots of text at once, maybe by chunking or some other 
technique. 

NOT IMPLEMENTING 
----------------
1. Effects: echo, panning, etc. These are going into swiftmac 2, which is a 
rewrite using different libraries with longer term future support. 
2. Mono-Mode: 

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
