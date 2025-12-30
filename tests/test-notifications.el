;;; test-notifications.el --- Test notification audio routing

;; Simple functions to test notification device routing

(defun test-notification-beep ()
  "Play a notification auditory icon - should go to notification device"
  (interactive)
  (emacspeak-auditory-icon 'select-object))

(defun test-multiple-notifications ()
  "Play several notifications in sequence"
  (interactive)
  (emacspeak-auditory-icon 'open-object)
  (sit-for 1)
  (emacspeak-auditory-icon 'close-object)
  (sit-for 1)
  (emacspeak-auditory-icon 'delete-object)
  (sit-for 1)
  (emacspeak-auditory-icon 'select-object))

(defun test-speech-only ()
  "Test regular speech - should go to speech device"
  (interactive)
  (dtk-speak "This is regular speech coming from the main speech device"))

(defun test-alternating ()
  "Alternate between speech and notifications to hear difference"
  (interactive)
  (dtk-speak "Speech device")
  (sit-for 1.5)
  (emacspeak-auditory-icon 'select-object)
  (sit-for 1)
  (dtk-speak "Speech again")
  (sit-for 1.5)
  (emacspeak-auditory-icon 'open-object)
  (sit-for 1)
  (dtk-speak "Final speech test")
  (sit-for 1.5)
  (emacspeak-auditory-icon 'close-object))

(message "Notification tests loaded. Use: (test-notification-beep) (test-multiple-notifications) (test-speech-only) (test-alternating)")

(provide 'test-notifications)
;;; test-notifications.el ends here
