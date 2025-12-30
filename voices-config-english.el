;;; voices-config-english.el --- English premium/enhanced voice mappings for swiftmac -*- lexical-binding: t; -*-

;; English voice personality definitions using PREMIUM and ENHANCED quality voices
;; Strategy: Premium voices for main text reading, Enhanced for highlights/annotations
;;
;; Voice mapping philosophy:
;; - MAIN TEXT (Premium Quality 3): animate, monotone, smoothen, indent
;; - HIGHLIGHTS/ANNOTATIONS (Enhanced Quality 2): bolden, brighten, lighten, annotate, overlay
;;
;; Voice assignments:
;; Premium (main reading):
;;   - Ava (Premium) - Female, lively → animate voices
;;   - Zoe (Premium) - Female, calm → monotone, smoothen voices
;;
;; Enhanced (highlights/annotations):
;;   - Evan (Enhanced) - Male, strong → bolden voices
;;   - Alex (Enhanced) - Male, friendly → brighten, lighten voices
;;   - Nathan (Enhanced) - Male, distinct → annotate, overlay voices

;; === MAIN TEXT VOICES (Premium Quality 3) ===

;; Animate voices - lively, energetic (using Ava Premium - for animated text)
(swiftmac-define-voice voice-animate "[{voice en-US:Ava (Premium)}] [[pitch 1]]")
(swiftmac-define-voice voice-animate-extra "[{voice en-US:Ava (Premium)}] [[pitch 1.5]]")
(swiftmac-define-voice voice-animate-medium "[{voice en-US:Ava (Premium)}] [[pitch 1.3]]")

;; Monotone voices - flat, neutral (using Zoe Premium - for neutral text)
(swiftmac-define-voice voice-monotone "[{voice en-US:Zoe (Premium)}] [[pitch 1]]")
(swiftmac-define-voice voice-monotone-extra "[{voice en-US:Zoe (Premium)}] [[pitch 1.5]]")
(swiftmac-define-voice voice-monotone-medium "[{voice en-US:Zoe (Premium)}] [[pitch 1.3]]")

;; Smoothen voices - calm, lower (using Zoe Premium - for calming text)
(swiftmac-define-voice voice-smoothen "[{voice en-US:Zoe (Premium)}] [[pitch 0.6]]")
(swiftmac-define-voice voice-smoothen-extra "[{voice en-US:Zoe (Premium)}] [[pitch 0.4]]")
(swiftmac-define-voice voice-smoothen-medium "[{voice en-US:Zoe (Premium)}] [[pitch 0.2]]")

;; Indent voice - distinctive for indentation (using Ava Premium with higher pitch)
(swiftmac-define-voice voice-indent "[{voice en-US:Ava (Premium)}] [[pitch 1.6]]")

;; === HIGHLIGHT/ANNOTATION VOICES (Enhanced Quality 2) ===

;; Annotate voice - distinct for annotations (using Nathan Enhanced)
(swiftmac-define-voice voice-annotate "[{voice en-US:Nathan}] [[pitch 1]]")

;; Bolden voices - strong, authoritative (using Evan Enhanced - deep male)
(swiftmac-define-voice voice-bolden "[{voice en-US:Evan}] [[pitch 1]]")
(swiftmac-define-voice voice-bolden-and-animate "[{voice en-US:Evan}] [[pitch 1.2]]")
(swiftmac-define-voice voice-bolden-extra "[{voice en-US:Evan}] [[pitch 1.4]]")
(swiftmac-define-voice voice-bolden-medium "[{voice en-US:Evan}] [[pitch 0.8]]")

;; Brighten voices - cheerful, lighter (using Alex Enhanced - friendly male)
(swiftmac-define-voice voice-brighten "[{voice en-US:Alex}] [[pitch 1]]")
(swiftmac-define-voice voice-brighten-extra "[{voice en-US:Alex}] [[pitch 1.2]]")
(swiftmac-define-voice voice-brighten-medium "[{voice en-US:Alex}] [[pitch 0.8]]")

;; Lighten voices - lighter tone (using Alex Enhanced with varied pitch)
(swiftmac-define-voice voice-lighten "[{voice en-US:Alex}] [[pitch 1]]")
(swiftmac-define-voice voice-lighten-extra "[{voice en-US:Alex}] [[pitch 1.4]]")
(swiftmac-define-voice voice-lighten-medium "[{voice en-US:Alex}] [[pitch 0.8]]")

;; Overlay voices - layered information (using Nathan Enhanced with pitch variation)
(swiftmac-define-voice voice-overlay-0 "[{voice en-US:Nathan}] [[pitch 1.1]]")
(swiftmac-define-voice voice-overlay-1 "[{voice en-US:Nathan}] [[pitch 1.3]]")
(swiftmac-define-voice voice-overlay-2 "[{voice en-US:Nathan}] [[pitch 1.5]]")
(swiftmac-define-voice voice-overlay-3 "[{voice en-US:Nathan}] [[pitch 1.7]]")

(provide 'voices-config-english)
;;; voices-config-english.el ends here
