TODO:
 - Finish python based test driver to validate functionality
 - Add signal handling (control-c, etc)
 - Add handling of voice changes (most of the plumbing is ready)
 - Add echo handling via custom NSSpeechSynthesizer with echo effect
 - Add custom dictionary objects to pronounce things rather than using
  string manipulation, might need a seperate speaker per class
 - (maybe) disable built-in voice on the fly as speaking to make it
  require zero configuration to use (no double speaking)  
 - (maybe) Switch to AVFoundation and utterances
  - Makes it easier to handle adding spee
  - All speech comes with its own voice and specifics like speed
  - Very much fits how emacspeak generates speech


MOTIVATIONS
 This is a port of the wonderful mac server for emacspeak, the reasons
 for the port are varied, but the key one was a lack of reliability
 when running the mac server for long periods of time, which I suspect
 is actually from the retention code deep in pyobjc but not sure.

 Goals:
 - Highly relibable (no memory leaks, no voiceover garble)
 - Completely non-blocking (never lag emacs)
 - Feature-complete (if emacspeak supports it we do)
 - No dependandies except swift (meaning xcode)
 - No install needed, compile on the fly with #!
 - Take full advantage of built-in VoiiceOver features 
