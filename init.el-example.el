;; Add this to your init.el to enable multi-device audio routing

(use-package emacspeak
  :ensure nil  ; Installed manually, not via package manager
  :init
  (setopt load-path (cons "~/.emacspeak/lisp" load-path))
  (setopt emacspeak-directory "~/.emacspeak")
  (setopt swiftmac-default-voice-string "[{voice :Samantha}] [[pitch 1]]")
  (setopt emacspeak-play-startup-icon nil)

  ;; MULTI-DEVICE ROUTING CONFIGURATION
  ;; Speech -> Audioengine D1 (device 125), both channels
  (setenv "SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL" "125:both")

  ;; Notifications -> LG Ultra HD (device 110), left channel only
  (setenv "SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL" "110:left")

  :config
  ; stops doubletalk (when supported)
  (setopt mac-ignore-accessibility 't)
  (setopt dtk-program "swiftmac")

  ; Volume controls (between 0.0 and 1.0)
  (setenv "SWIFTMAC_TONE_VOLUME" "0.1")
  (setenv "SWIFTMAC_SOUND_VOLUME" "0.1")
  (setenv "SWIFTMAC_VOICE_VOLUME" "1.0")

  ;; IMPORTANT: Enable notification server for multi-device routing
  ;; This tells Emacspeak to spawn a second swiftmac process for notifications
  ;; You can use "left", "right", "notify", or any non-"default" value
  (setopt tts-notification-device "left")

  (require 'emacspeak-setup))
