swiftmac
========
This is a drop in replacement for the python "mac" server that comes 
with emacspeak. The goal is to get it mainlined into Emacspeak once
it is feature complete.

You can look at TODO (toward end of this file) to see if it is 
missing critical features for your use case.

Quick Install
-------------
1. Open Makefile, make sure first two lines point to your emacspeak
2. Make install 
3. Change the server in your init.el from "mac" to "swiftmac"
4. Restart emacs

Motivation
----------
 I wanted a mac experience with a few things that are presently not 
 possible in the mac python server. 
 1. No deps except swift
 2. Compiled and multithread for complete non-blocking operations 
 3. Highly reliable, will never corrupt speech on MacOS
 4. Drop in (no configuration or special setup required in Eamcs or 
    the operating system.
 5. Feature complete support of all emacs speech server commands
 6. With a separate test script to confirm all features work 
 

TODO
----
 - Support voice changes (why are so many changes spammed?)
 - Add an error handling delegate
 - Add handing for beep caps (entirely) 
 - Finish handling splitCaps 
 - Finish python based test driver to validate functionality
 - Add echo handling via custom NSSpeechSynthesizer with echo effect
 
