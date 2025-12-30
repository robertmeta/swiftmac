;;; minimal-emacspeak-init.el --- Minimal Emacspeak config for testing

;; Minimal configuration for testing Emacspeak with swiftmac
;; This file contains only the essential Emacspeak setup without
;; any other packages or personal configuration

;; Emacspeak configuration (based on user's init.el)
(setopt load-path (cons "~/.emacspeak/lisp" load-path))
(setopt emacspeak-directory "~/.emacspeak")
(setopt swiftmac-default-voice-string "[{voice :Samantha}] [[pitch 1]]")
(setopt emacspeak-play-startup-icon nil)

;; Configure swiftmac
(setopt mac-ignore-accessibility 't)
(setopt dtk-program "swiftmac")

;; Set audio volumes
(setenv "SWIFTMAC_TONE_VOLUME" "0.1")
(setenv "SWIFTMAC_SOUND_VOLUME" "0.1")
(setenv "SWIFTMAC_VOICE_VOLUME" "1.0")

;; Set notification device
(setopt tts-notification-device "right")

;; Load Emacspeak
(require 'emacspeak-setup)

;;; minimal-emacspeak-init.el ends here
