;;; test-simple-routing.el --- Simple speech device routing test

;; Simple test: Just speak something to verify device routing works

(defun test-speech-simple ()
  "Test speech output - should go to configured speech device"
  (interactive)
  (dtk-speak "This is a speech test on the main device"))

(defun test-speech-long ()
  "Test longer speech to give time to verify which device it's using"
  (interactive)
  (dtk-speak "This is a longer speech test. You should hear this coming from the Audioengine D1 device on both channels. If you hear this correctly, device routing is working."))

(message "Simple speech test loaded. Run: (test-speech-simple) or (test-speech-long)")

(provide 'test-simple-routing)
;;; test-simple-routing.el ends here
