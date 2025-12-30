;;; markdown-voices-config.el --- Voice configuration for markdown mode

;; Custom voice configuration for markdown with different US voices

;; Define custom voices for markdown elements
;; Format: [{voice <lang>:<name>}] [[pitch <multiplier>]]

;; Bold - Strong emphasis with Fred (deeper voice)
(swiftmac-define-voice 'voice-markdown-bold
                       "[{voice en-US:Fred}] [[pitch 0.8]]")

;; Italic - Emphasis with Samantha (slightly higher pitch)
(swiftmac-define-voice 'voice-markdown-italic
                       "[{voice en-US:Samantha}] [[pitch 1.1]]")

;; Code/Inline Code - Monotone with Alex (neutral)
(swiftmac-define-voice 'voice-markdown-code
                       "[{voice en-US:Alex}] [[pitch 0.9]]")

;; Links - Distinctive with Tom
(swiftmac-define-voice 'voice-markdown-link
                       "[{voice en-US:Tom}] [[pitch 1.0]]")

;; URLs - Faster, lower pitch with Ralph
(swiftmac-define-voice 'voice-markdown-url
                       "[{voice en-US:Ralph}] [[pitch 0.85]]")

;; Heading Level 1 - Bold with Vicki
(swiftmac-define-voice 'voice-markdown-h1
                       "[{voice en-US:Vicki}] [[pitch 0.75]]")

;; Heading Level 2 - Kathy
(swiftmac-define-voice 'voice-markdown-h2
                       "[{voice en-US:Kathy}] [[pitch 0.85]]")

;; Heading Level 3 - Victoria
(swiftmac-define-voice 'voice-markdown-h3
                       "[{voice en-US:Victoria}] [[pitch 0.95]]")

;; Heading Level 4 - Bruce
(swiftmac-define-voice 'voice-markdown-h4
                       "[{voice en-US:Bruce}] [[pitch 1.0]]")

;; Heading Level 5 - Tom
(swiftmac-define-voice 'voice-markdown-h5
                       "[{voice en-US:Tom}] [[pitch 1.05]]")

;; Heading Level 6 - Fred (lighter)
(swiftmac-define-voice 'voice-markdown-h6
                       "[{voice en-US:Fred}] [[pitch 1.1]]")

;; Blockquote - Softer with Samantha
(swiftmac-define-voice 'voice-markdown-blockquote
                       "[{voice en-US:Samantha}] [[pitch 0.95]]")

;; List markers - Quick with Alex
(swiftmac-define-voice 'voice-markdown-list
                       "[{voice en-US:Alex}] [[pitch 1.0]]")

;; Pre/Code blocks - Monotone Alex
(swiftmac-define-voice 'voice-markdown-pre
                       "[{voice en-US:Alex}] [[pitch 0.9]]")

;; Metadata/Front matter - Softer Ralph
(swiftmac-define-voice 'voice-markdown-metadata
                       "[{voice en-US:Ralph}] [[pitch 1.0]]")

;; Map markdown faces to our custom voices
(voice-setup-add-map
 '(
   ;; Text emphasis
   (markdown-bold-face voice-markdown-bold)
   (markdown-italic-face voice-markdown-italic)
   (markdown-bold-italic-face voice-bolden-and-animate)  ; Use built-in combo
   (markdown-strike-through-face voice-monotone-extra)

   ;; Code
   (markdown-code-face voice-markdown-code)
   (markdown-inline-code-face voice-markdown-code)
   (markdown-pre-face voice-markdown-pre)
   (markdown-language-keyword-face voice-smoothen)
   (markdown-language-info-face voice-smoothen)

   ;; Links
   (markdown-link-face voice-markdown-link)
   (markdown-url-face voice-markdown-url)
   (markdown-link-title-face voice-animate)
   (markdown-reference-face voice-lighten)

   ;; Headings
   (markdown-header-face-1 voice-markdown-h1)
   (markdown-header-face-2 voice-markdown-h2)
   (markdown-header-face-3 voice-markdown-h3)
   (markdown-header-face-4 voice-markdown-h4)
   (markdown-header-face-5 voice-markdown-h5)
   (markdown-header-face-6 voice-markdown-h6)

   ;; Lists
   (markdown-list-face voice-markdown-list)
   (markdown-blockquote-face voice-markdown-blockquote)

   ;; Metadata
   (markdown-metadata-key-face voice-markdown-metadata)
   (markdown-metadata-value-face voice-lighten)

   ;; Tables
   (markdown-table-face voice-smoothen)

   ;; Other
   (markdown-math-face voice-brighten)
   (markdown-footnote-marker-face voice-animate-extra)
   (markdown-comment-face voice-annotate)
   ))

(message "Markdown voice configuration loaded with US voices!")
(message "Voices: Bold=Fred, Italic=Samantha, Links=Tom, Code=Alex")
(message "Headings: H1=Vicki, H2=Kathy, H3=Victoria, H4=Bruce, H5=Tom, H6=Fred")

(provide 'markdown-voices-config)
;;; markdown-voices-config.el ends here
