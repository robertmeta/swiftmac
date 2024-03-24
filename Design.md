## Design

The server intends to provide primitives to support all the features used by
emacspeak and swiftmac-voices.el.


## Supported Commands

These are the commands sent via stdin and on thier own line.

- ```a```: queue audio icon
- ```c```: queue code
- ```d```: dispatch queue
- ```l```: instant letter
- ```p```: instant audio icon
- ```q```: queue speech
- ```s```: stop all (confirm with list)_
- ```sh```: queue silence
- ```t```: queue tone
- ```tts_pause```: instant pause speech engine (should stop?)
- ```tts_reset```: queue reset (to defaults?)
- ```tts_resume```: instant resume speech engine
- ```tts_say```: instant say no additional tweaking
- ```tts_set_character_scale```: queue char scale change
- ```tts_set_punctuations```: queue punct change
- ```tts_set_speech_rate```: queue rate change
- ```tts_split_caps```: queue split caps change
- ```tts_sync_state```: [decomp] queue multiple settings change
- ```version```: [decomp] say tts version

Engine Specific:
- ```tts_exit```: instant exit
- ```tts_set_pitch_multiplier```: .5 to 2 pitch multiplier
- ```tts_set_sound_volume```: 0 to 1 (1 being 100% sound volume)
- ```tts_set_tone_volume```: 0 to 1 (1 being 100% tone volume)
- ```tts_set_voice```: queue voice change
- ```tts_set_voice_volume```: 0 to 1 (1 being 100% voice volume)

Broken:
- ```tts_allcaps_beep```: queue caps beep change, setting only works on typing
  input


## Supported Embeddings

These are converted by the preprocessor into tts_ commands.

- [{voice Foo}] - queue switch to voice best attempt (default fallback)
- [*] - queue silence in place of this


## Overview 

### Main

The SwiftMac Text-to-Speech program is a command-line tool that processes
various text-to-speech commands and generates audio output using the
AVFoundation framework in Swift. The program supports features such as speech
synthesis, audio playback, tone generation, and customization of speech
parameters.  Program Flow

1. Main Function The program starts with the main() function, which initializes
   the necessary components and enters a loop to read and process commands from
   the standard input. Each command is isolated into a command and its
   parameters using the isolateCmdAndParams() function. Based on the command,
   the corresponding processing function is called.

2. Command Processing 

The program supports several commands, including:

Each command has a corresponding processing function that handles the specific
task.

Commands are either handled in the main loop (instants) or queued for 
processing on a dispatch event.

3. Pending Queue Some commands are queued for later processing using the
queueLine() function. These queued commands are stored in the StateStore
object. The dispatchPendingQueue() function is responsible for processing the
queued commands in the order they were added.

4. Speech Synthesis The processAndQueueSpeech() function processes the input
text, applies punctuation replacements, and splits the text into smaller chunks
if necessary. The processed text is then queued for speech synthesis using the
doSpeak() function.

5. Audio Playback The doPlaySound() function is responsible for playing audio
files. It supports both WAV and OGG formats. OGG files are decoded using the
OGGDecoder class before playback.

6. Tone Generation The doTone() function generates pure tones using the
TonePlayerActor class. It takes the frequency and duration of the tone as
parameters.

### StateStore 

The StateStore class is responsible for managing the program's state, including
the pending queue, text-to-speech parameters, and various flags. It provides
functions to set and retrieve these parameters.

### Logging 

The program includes a logging mechanism using the Logger class. In debug mode,
the logger writes log messages to a file with a timestamp. In release mode, the
logger is a no-op.

### Utility Functions 

The program includes several utility functions for tasks such as extracting
voice information from text, replacing punctuations, checking if a string starts
with a capital letter, and more. These functions are used throughout the program
to process and manipulate text.
