Worklog
=======
2023-04-03 - Robert Melton
--------------------------
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
