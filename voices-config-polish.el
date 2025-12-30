;;; voices-config-polish.el --- Polish voice mappings for swiftmac -*- lexical-binding: t; -*-

;; Polish voice personality definitions using pl-PL voices
;; Original configuration from user's markdown example

;; Animate voices - lively, energetic (using Ewa - female)
(swiftmac-define-voice voice-animate "[{voice pl-PL:Ewa}] [[pitch 1]]")
(swiftmac-define-voice voice-animate-extra "[{voice pl-PL:Ewa}] [[pitch 1.5]]")
(swiftmac-define-voice voice-animate-medium "[{voice pl-PL:Ewa}] [[pitch 1.3]]")

;; Annotate voice - distinct for annotations (using Iven - male)
(swiftmac-define-voice voice-annotate "[{voice pl-PL:Iven}] [[pitch 1]]")

;; Bolden voices - strong, authoritative (using Max - male)
(swiftmac-define-voice voice-bolden "[{voice pl-PL:Max}] [[pitch 1]]")
(swiftmac-define-voice voice-bolden-and-animate "[{voice pl-PL:Max}] [[pitch 1.2]]")
(swiftmac-define-voice voice-bolden-extra "[{voice pl-PL:Max}] [[pitch 1.4]]")
(swiftmac-define-voice voice-bolden-medium "[{voice pl-PL:Max}] [[pitch 0.8]]")

;; Brighten voices - cheerful, lighter (using Adam - male)
(swiftmac-define-voice voice-brighten "[{voice pl-PL:Adam}] [[pitch 1]]")
(swiftmac-define-voice voice-brighten-extra "[{voice pl-PL:Adam}] [[pitch 1.2]]")
(swiftmac-define-voice voice-brighten-medium "[{voice pl-PL:Adam}] [[pitch 0.8]]")

;; Indent voice - distinctive for indentation (using Zosia - female)
(swiftmac-define-voice voice-indent "[{voice pl-PL:Zosia}] [[pitch 1.6]]")

;; Lighten voices - lighter tone (using Krzysztof - male)
(swiftmac-define-voice voice-lighten "[{voice pl-PL:Krzysztof}] [[pitch 1]]")
(swiftmac-define-voice voice-lighten-extra "[{voice pl-PL:Krzysztof}] [[pitch 1.4]]")
(swiftmac-define-voice voice-lighten-medium "[{voice pl-PL:Krzysztof}] [[pitch 0.8]]")

;; Monotone voices - flat, neutral (using Zosia - female)
(swiftmac-define-voice voice-monotone "[{voice pl-PL:Zosia}] [[pitch 1]]")
(swiftmac-define-voice voice-monotone-extra "[{voice pl-PL:Zosia}] [[pitch 1.5]]")
(swiftmac-define-voice voice-monotone-medium "[{voice pl-PL:Zosia}] [[pitch 1.3]]")

;; Overlay voices - layered information (using Robert - male)
(swiftmac-define-voice voice-overlay-0 "[{voice pl-PL:Robert}] [[pitch 1.1]]")
(swiftmac-define-voice voice-overlay-1 "[{voice pl-PL:Robert}] [[pitch 1.3]]")
(swiftmac-define-voice voice-overlay-2 "[{voice pl-PL:Robert}] [[pitch 1.5]]")
(swiftmac-define-voice voice-overlay-3 "[{voice pl-PL:Robert}] [[pitch 1.7]]")

;; Smoothen voices - calm, lower (using Zosia - female)
(swiftmac-define-voice voice-smoothen "[{voice pl-PL:Zosia}] [[pitch 0.6]]")
(swiftmac-define-voice voice-smoothen-extra "[{voice pl-PL:Zosia}] [[pitch 0.4]]")
(swiftmac-define-voice voice-smoothen-medium "[{voice pl-PL:Zosia}] [[pitch 0.2]]")

(provide 'voices-config-polish)
;;; voices-config-polish.el ends here
