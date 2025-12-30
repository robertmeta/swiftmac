;;; test-runtime-device-switching.el --- Test runtime device switching

;; Test functions for runtime device switching

;; Device IDs (from make list-devices):
;; 125 = Audioengine D1 (default)
;; 110 = LG Ultra HD
;; 89  = MacBook Pro Speakers

(defun test-switch-to-audioengine ()
  "Switch speech to Audioengine D1 (device 125)"
  (interactive)
  (dtk-dispatch "tts_set_speech_device 125")
  (sit-for 0.5)
  (dtk-speak "Now speaking from Audioengine D 1"))

(defun test-switch-to-lg ()
  "Switch speech to LG Ultra HD (device 110)"
  (interactive)
  (dtk-dispatch "tts_set_speech_device 110")
  (sit-for 0.5)
  (dtk-speak "Now speaking from L G Ultra H D"))

(defun test-switch-to-macbook ()
  "Switch speech to MacBook Pro Speakers (device 89)"
  (interactive)
  (dtk-dispatch "tts_set_speech_device 89")
  (sit-for 0.5)
  (dtk-speak "Now speaking from MacBook Pro speakers"))

(defun test-device-tour ()
  "Tour all three devices with speech"
  (interactive)
  (dtk-speak "Starting device tour")
  (sit-for 2)

  (dtk-dispatch "tts_set_speech_device 125")
  (sit-for 0.5)
  (dtk-speak "Device 1 2 5: Audioengine D 1")
  (sit-for 3)

  (dtk-dispatch "tts_set_speech_device 110")
  (sit-for 0.5)
  (dtk-speak "Device 1 1 0: L G Ultra H D")
  (sit-for 3)

  (dtk-dispatch "tts_set_speech_device 89")
  (sit-for 0.5)
  (dtk-speak "Device 8 9: MacBook Pro speakers")
  (sit-for 3)

  ;; Return to default
  (dtk-dispatch "tts_set_speech_device 125")
  (sit-for 0.5)
  (dtk-speak "Tour complete. Back to Audioengine D 1"))

(defun test-channel-switching ()
  "Test channel switching on current device"
  (interactive)
  (dtk-speak "Testing channels on current device")
  (sit-for 2)

  (dtk-dispatch "tts_set_speech_channel left")
  (sit-for 0.5)
  (dtk-speak "Left channel only")
  (sit-for 2)

  (dtk-dispatch "tts_set_speech_channel right")
  (sit-for 0.5)
  (dtk-speak "Right channel only")
  (sit-for 2)

  (dtk-dispatch "tts_set_speech_channel both")
  (sit-for 0.5)
  (dtk-speak "Both channels. Stereo mode"))

(defun test-device-and-channel ()
  "Test switching both device and channel"
  (interactive)
  (dtk-speak "Testing device and channel combinations")
  (sit-for 2)

  ;; LG left
  (dtk-dispatch "tts_set_speech_device 110")
  (dtk-dispatch "tts_set_speech_channel left")
  (sit-for 0.5)
  (dtk-speak "L G left channel")
  (sit-for 2)

  ;; LG right
  (dtk-dispatch "tts_set_speech_channel right")
  (sit-for 0.5)
  (dtk-speak "L G right channel")
  (sit-for 2)

  ;; Audioengine both
  (dtk-dispatch "tts_set_speech_device 125")
  (dtk-dispatch "tts_set_speech_channel both")
  (sit-for 0.5)
  (dtk-speak "Audioengine both channels"))

(message "Runtime device switching tests loaded!")
(message "Commands: test-switch-to-audioengine, test-switch-to-lg, test-switch-to-macbook")
(message "          test-device-tour, test-channel-switching, test-device-and-channel")

(provide 'test-runtime-device-switching)
;;; test-runtime-device-switching.el ends here
