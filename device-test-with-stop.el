;;; Device switching tests with speech stop

;; Helper function to stop, switch device, then speak
(defun test-device-switch (device-id device-name)
  "Stop speech, switch device, then speak from new device"
  (dtk-stop)  ; Stop current speech
  (sit-for 0.3)
  (dtk-dispatch (format "tts_set_speech_device %s" device-id))
  (sit-for 0.3)
  (dtk-speak (format "Now speaking from %s" device-name)))

;; Test LG Ultra HD
(test-device-switch "110" "L G Ultra H D")

;; Test MacBook speakers
(test-device-switch "89" "MacBook Pro speakers")

;; Test Audioengine D1
(test-device-switch "125" "Audioengine D 1")

;; Tour all devices
(defun device-tour ()
  "Tour through all three devices"
  (interactive)
  (test-device-switch "125" "Audioengine D 1")
  (sit-for 3)
  (test-device-switch "110" "L G Ultra H D")
  (sit-for 3)
  (test-device-switch "89" "MacBook Pro speakers")
  (sit-for 3)
  (test-device-switch "125" "back to Audioengine D 1"))

;; Simple quick test
(defun quick-switch-test ()
  "Quick switch between two devices"
  (interactive)
  (dtk-stop)
  (dtk-dispatch "tts_set_speech_device 110")
  (sit-for 0.5)
  (dtk-speak "L G")
  (sit-for 2)
  (dtk-stop)
  (dtk-dispatch "tts_set_speech_device 125")
  (sit-for 0.5)
  (dtk-speak "Audioengine"))

;; Use: (device-tour) or (quick-switch-test)
