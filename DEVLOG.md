Devlog
======
2023-04-21 - Robert Melton
--------------------------
 - Better install process with detection of location of emacspeak

2023-04-18 - Robert Melton
--------------------------
 - Moved TODO to github issues
 - Renamed Worklog to devlog 
 - Added recommended settings 
 - Added backing up of old working swiftmacs on install 

2023-04-04 - Robert Melton
--------------------------
 - I added in fat binaries and curl downloads for them, need a 
   sane way to update the github releases 
 - I think it is just good enough to announce today and ask some 
   questions, after I finished debug mode so people can send in 
   debug logs.
 - now generating debug logs so it should be able to produce usefu 
   feedback from users of debug builds.
 - added SWIFTMAC_SOUND_VOLUME, SWIFTMAC_VOICE_VOLUME and 
   SWIFTMAC_TONE_VOLUME for being able to tweak them via env

2023-04-03 - Robert Melton
--------------------------
 - TODO: log the debug to a file so crashes can be debugged, make it 
   flush too.
 - Fixed up debug mode with real checks
 - Hunted down any obvious crashes 
 - Converted to a proper swift project with a pre-build step to make
   it more like a proper swift app and fit in the swift ecosystem
 - Still missing major features (voice change, how do split caps 
   work, etc) - the voice change thing is strange, it seems to be 
   spammed as a way to do a tts_reset.

2023-04-02 - Robert Melton
--------------------------
 - Tomorrow a few implmentations left, then release 1.0
 - Tomorrow need to wrap everything in try/catch no crashes
 - Realized after I did the debugging work that it was the dumbest 
   possible way, need to make it a function that can write to a file 
   that it pulls the name from environment
 - I now understand why so many commands for setting the voice come 
   in, it is as a soft reset of the voice server, better implemented
   with [[reset 0]] 
 - Now onto how the original mac server doens't spam char when typing
   quickly, cause that is much better quality of life
 - https://tinyurl.com/2r3g9ls6 - the embed codes for VoiceOver

2023-04-01 - Robert Melton
--------------------------
 - Starting to use it daily, bugs should work out a lot quicker now
 - Need to handle [*]
 - Need to find why we get stuck in char mode 
