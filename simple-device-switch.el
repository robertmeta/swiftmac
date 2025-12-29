;;; Simple device switching tests - run one at a time

;; Test 1: Switch to LG Ultra HD and speak
(defun switch-to-lg ()
  (interactive)
  (dtk-stop)
  (dtk-dispatch "tts_set_speech_device 110")
  (dtk-speak "Now on L G Ultra H D"))

;; Test 2: Switch to MacBook speakers and speak
(defun switch-to-macbook ()
  (interactive)
  (dtk-stop)
  (dtk-dispatch "tts_set_speech_device 89")
  (dtk-speak "Now on MacBook speakers"))

;; Test 3: Switch to Audioengine D1 and speak
(defun switch-to-audioengine ()
  (interactive)
  (dtk-stop)
  (dtk-dispatch "tts_set_speech_device 125")
  (dtk-speak "Now on Audioengine D 1"))

;; Test current device
(defun test-current-device ()
  (interactive)
  (dtk-speak "Testing current device"))

;; Instructions:
;; Run each function manually to test device switching:
;;
;; M-x switch-to-lg          (or eval: (switch-to-lg))
;; M-x switch-to-macbook     (or eval: (switch-to-macbook))
;; M-x switch-to-audioengine (or eval: (switch-to-audioengine))
;; M-x test-current-device   (or eval: (test-current-device))
;;
;; You should hear the audio come from different devices!
