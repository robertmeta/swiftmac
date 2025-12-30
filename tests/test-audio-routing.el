;;; test-audio-routing.el --- Test audio routing for swiftmac

;; Test functions for verifying multi-device audio routing

(defun test-speech ()
  "Test speech routing - should go to SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL"
  (interactive)
  (dtk-speak "Testing speech output on main speech device"))

(defun test-notification ()
  "Test notification routing - should go to SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL"
  (interactive)
  (emacspeak-auditory-icon 'select-object))

(defun test-tone ()
  "Test tone routing - should go to SWIFTMAC_TONE_DEVICE_AND_CHANNEL"
  (interactive)
  (dtk-tone 500 100))

(defun test-all-streams ()
  "Test all audio streams in sequence"
  (interactive)
  (dtk-speak "Testing speech")
  (sit-for 2)
  (dtk-speak "Testing notification")
  (sit-for 0.5)
  (emacspeak-auditory-icon 'select-object)
  (sit-for 2)
  (dtk-speak "Testing tone")
  (sit-for 0.5)
  (dtk-tone 800 150)
  (sit-for 2)
  (dtk-speak "Test complete"))

(defun test-speech-left-right ()
  "Test speech left vs right channel if using channel routing"
  (interactive)
  (dtk-speak "Testing left channel")
  (sit-for 2)
  (dtk-speak "This should be in the configured channel"))

(defun test-rapid-alternating ()
  "Rapidly alternate between speech and notifications to hear difference"
  (interactive)
  (dotimes (i 3)
    (dtk-speak "Speech")
    (sit-for 0.8)
    (emacspeak-auditory-icon 'select-object)
    (sit-for 0.8)))

;; Key bindings for quick testing
(global-set-key (kbd "C-c t s") 'test-speech)
(global-set-key (kbd "C-c t n") 'test-notification)
(global-set-key (kbd "C-c t o") 'test-tone)
(global-set-key (kbd "C-c t a") 'test-all-streams)
(global-set-key (kbd "C-c t r") 'test-rapid-alternating)

(message "Audio routing tests loaded. Use C-c t [s/n/o/a/r] to test streams")

(provide 'test-audio-routing)
;;; test-audio-routing.el ends here
