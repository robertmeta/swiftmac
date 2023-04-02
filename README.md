TODO:
 - Finish python based test driver to validate functionality
 - Add signal handling (control-c, etc)
 - Add echo handling via custom NSSpeechSynthesizer with echo effect
 - Make compile an option for generatoring a binary so it will work 
   with no setup or they can use make swiftmac as an alternative

MOTIVATIONS:
 This is a port of the wonderful mac server for emacspeak, the reasons
 for the port are varied, but the key one was a lack of reliability
 when running the mac server for long periods of time, which I suspect
 is actually from the retention code deep in pyobjc but not sure.

 GOALS:
 - Highly relibable (no memory leaks, no voiceover garble, self-resets
   on error
 - Completely non-blocking (never lag emacs)
 - Feature-complete (if emacspeak supports it we do)
 - No dependandies except swift (meaning xcode)
 - No install needed, compile on the fly with #!
 - Take full advantage of built-in VoiiceOver features 
