;;; list-voices.el --- Interactive voice browser for swiftmac -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Robert Melton

;; Interactive tool to browse and sample all installed macOS voices

;;; Commentary:
;; This provides an interactive buffer listing all available voices
;; Press RET on a voice to hear it speak a sample phrase

;;; Code:

(require 'cl-lib)

(defvar swiftmac-voice-list-buffer "*Voice List*"
  "Buffer name for voice listing.")

(defvar swiftmac-voice-sample-text "Hello, this is a sample of my voice."
  "Text to speak when sampling a voice.")

(defvar swiftmac-voice-list nil
  "Cached list of available voices.")

(defun swiftmac-parse-voice-line (line)
  "Parse a voice LINE from say -v '?' output.
Returns (name locale quality-level description) or nil."
  (when (string-match "^\\([^[:space:]]+\\(?:[[:space:]][^[:space:]]+\\)*?\\)[[:space:]]+\\([a-z_]+\\)[[:space:]]+#" line)
    (let* ((name (string-trim (match-string 1 line)))
           (locale (match-string 2 line))
           (quality (cond
                     ((string-match "(Premium)" name) "Premium")
                     ((string-match "(Enhanced)" name) "Enhanced")
                     (t "Compact")))
           (desc (when (string-match "#\\s-*\\(.+\\)" line)
                   (match-string 1 line))))
      (list name locale quality desc))))

(defun swiftmac-get-voices ()
  "Get list of all available voices from macOS.
Returns list of (name locale quality description)."
  (unless swiftmac-voice-list
    (let ((output (shell-command-to-string "say -v '?'"))
          voices)
      (dolist (line (split-string output "\n" t))
        (when-let ((parsed (swiftmac-parse-voice-line line)))
          (push parsed voices)))
      (setq swiftmac-voice-list (nreverse voices))))
  swiftmac-voice-list)

(defun swiftmac-speak-with-voice (voice-name text)
  "Speak TEXT using VOICE-NAME via macOS say command."
  (start-process "swiftmac-sample" nil "say" "-v" voice-name text))

(defun swiftmac-sample-voice-at-point ()
  "Sample the voice at point in the voice list buffer."
  (interactive)
  (let ((voice-name (get-text-property (point) 'voice-name)))
    (if voice-name
        (progn
          (message "Sampling voice: %s" voice-name)
          (swiftmac-speak-with-voice voice-name swiftmac-voice-sample-text))
      (message "No voice at point"))))

(defun swiftmac-stop-all-voices ()
  "Stop all currently speaking voices."
  (interactive)
  (shell-command "killall say")
  (message "Stopped all voices"))

(defvar swiftmac-voice-list-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'swiftmac-sample-voice-at-point)
    (define-key map (kbd "s") 'swiftmac-sample-voice-at-point)
    (define-key map (kbd "q") 'quit-window)
    (define-key map (kbd "x") 'swiftmac-stop-all-voices)
    (define-key map (kbd "g") 'swiftmac-list-voices)
    map)
  "Keymap for swiftmac voice list mode.")

(define-derived-mode swiftmac-voice-list-mode special-mode "Voice-List"
  "Major mode for browsing and sampling macOS voices.

Commands:
\\{swiftmac-voice-list-mode-map}"
  (setq buffer-read-only t))

;;;###autoload
(defun swiftmac-list-voices ()
  "Display an interactive list of all available macOS voices.
Press RET or 's' on a voice to sample it.
Press 'x' to stop all speaking.
Press 'q' to quit the buffer."
  (interactive)
  (let ((voices (swiftmac-get-voices)))
    (with-current-buffer (get-buffer-create swiftmac-voice-list-buffer)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (swiftmac-voice-list-mode)

        ;; Header
        (insert (propertize "macOS Voice Browser\n" 'face 'bold))
        (insert (propertize (format "Total voices: %d\n" (length voices)) 'face 'italic))
        (insert (propertize "Press RET/s to sample, x to stop, q to quit\n\n" 'face 'italic))

        ;; Group voices by quality
        (dolist (quality '("Premium" "Enhanced" "Compact"))
          (let ((quality-voices (cl-remove-if-not
                                 (lambda (v) (string= (nth 2 v) quality))
                                 voices)))
            (when quality-voices
              (insert (propertize (format "\n=== %s Quality (%d voices) ===\n\n"
                                          quality (length quality-voices))
                                  'face 'bold))

              ;; Group by locale within quality
              (let ((locales (delete-dups (mapcar #'cadr quality-voices))))
                (dolist (locale (sort locales #'string<))
                  (let ((locale-voices (cl-remove-if-not
                                        (lambda (v) (string= (cadr v) locale))
                                        quality-voices)))
                    (insert (propertize (format "  %s:\n" locale)
                                        'face 'underline))
                    (dolist (voice locale-voices)
                      (let ((name (car voice))
                            (desc (nth 3 voice))
                            (start (point)))
                        (insert (format "    %-30s  %s\n" name (or desc "")))
                        (put-text-property start (point) 'voice-name name)
                        (put-text-property start (point) 'mouse-face 'highlight)))
                    (insert "\n")))))))

        (goto-char (point-min))
        (forward-line 4))
      (switch-to-buffer (current-buffer)))))

(provide 'list-voices)
;;; list-voices.el ends here
