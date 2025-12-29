;;; Simple device switching tests - evaluate these one at a time

;; First, speak to confirm current device
(dtk-speak "Starting on current device")

;; Switch to LG Ultra HD (110) and test
(progn
  (dtk-dispatch "tts_set_speech_device 110")
  (sit-for 0.5)
  (dtk-speak "Now on L G Ultra H D"))

;; Switch to MacBook speakers (89) and test
(progn
  (dtk-dispatch "tts_set_speech_device 89")
  (sit-for 0.5)
  (dtk-speak "Now on MacBook speakers"))

;; Switch back to Audioengine D1 (125) and test
(progn
  (dtk-dispatch "tts_set_speech_device 125")
  (sit-for 0.5)
  (dtk-speak "Now on Audioengine D 1"))

;; Test channel switching on current device
(progn
  (dtk-dispatch "tts_set_speech_channel left")
  (sit-for 0.5)
  (dtk-speak "Left channel only"))

(progn
  (dtk-dispatch "tts_set_speech_channel right")
  (sit-for 0.5)
  (dtk-speak "Right channel only"))

(progn
  (dtk-dispatch "tts_set_speech_channel both")
  (sit-for 0.5)
  (dtk-speak "Both channels"))

;; Combined test - device and channel
(progn
  (dtk-dispatch "tts_set_speech_device 110")
  (dtk-dispatch "tts_set_speech_channel left")
  (sit-for 0.5)
  (dtk-speak "L G left channel only"))

;; Reset to defaults
(progn
  (dtk-dispatch "tts_set_speech_device 125")
  (dtk-dispatch "tts_set_speech_channel both")
  (sit-for 0.5)
  (dtk-speak "Back to Audioengine D 1 both channels"))
