## Design

The server intends to provide primitives to support all the features used by
emacspeak and swiftmac-voices.el.

## Supported Commands

These are the commands sent via stdin and on thier own line.

- a: queue audio icon
- c: queue code
- d: dispatch queue
- l: instant letter
- p: instant audio icon
- q: queue speech
- s: stop all (confirm with list)_
- sh: queue silence
- t: queue tone
- tts_version: [decomp] say tts version
- tts_pause: instant pause speech engine (should stop?)
- tts_reset: queue reset (to defaults?)
- tts_resume: instant resume speech engine
- tts_say: [decomp] instant say
- tts_set_character_scale: queue char scale change
- tts_set_punctuations: queue punct change
- tts_set_speech_rate: queue rate change
- tts_discard: queue discard setting update
- tts_split_caps: queue split caps change
- tts_allcaps_beep: queue caps beep change
- tts_sync_state: [decomp] queue multiple settings change
- tts_exit: [engine specific] instant exit
- tts_set_voice: [engine specific] queue voice change
- tts_set_pitch_multiplier: [engine specific] +- pitch modulation


## Supported Embeddings

These are converted by the preprocessor into tts_ commands.

- [{voice Foo}] - queue switch to voice best attempt (default fallback)
- [[pmod ##]] - queue (+,-)## pitch modification + by default, can be + or -
- [[rate ##]] - queue ## rate setting


## Flow

CurrentState
ActiveQueue 
PendingQueue

One single worker loop:

- Wait STDIN
- Decompose if needed
- Dispatch if needed (move pending -> active
- Work active queue
- Loop through active FIFO Queue, empty it 
- Back to waiting


The server attempts to maintain a simple design.  Major components are:

- PresentState: the state of the actively output line, includes rate, pitchmod,
  etc
- PendingQueue: the waiting command list (processed by dispatch or discarded)

- STDIN loop:
 - Get line
 - Decompose line to 0 to N lines
 - foreach line:
  - handle line (action or stack on pending)

- RawQueue: untouched queue, commands that came in, used unless it is an instant
  command (s, tts_say)
- PendingQueue: expanded/preprocessed commands waiting ot be dispatched
- ActiveQueue: expended/preprocessed commands being actively handled

Those queues are handled by 3 loops that run concurrently:
- InputProcessor: handles stdin, preprocesses the line for if it needs to get
  baked down to more commands and it checks for "s" or similar the pending
  queue.
- Preprocessor: reads from raw queue, does converting if needed from embedded
  commands to direct tts_ commands, and moves that item from raw to pending or
  active based on type.
- OutputProcessor: reads from ActiveQueue which is already cleaned up by
  preprocessor, send to sound player, tone player or speech player and of course
  modify state.

Example: tts_sync_state ...  decompose to: tts_set_rate tts_set ...  tts_say ...
 decompose to: s q ...  d
 
