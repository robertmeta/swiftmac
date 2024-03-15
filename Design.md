{# Design

The server intends to provide primitives to support all
the features used by emacspeak and swiftmac-voices.el.

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
- tts_version: say tts version
- tts_exit: instant exit
- tts_pause: instant pause speech engine
- tts_reset: queue reset
- tts_resume: instant resume speech engine
- tts_say: instant say
- tts_set_character_scale: queue char scale change
- tts_set_punctuations: queue punct change
- tts_set_speech_rate: queue rate change
- tts_split_caps: queue split caps change
- tts_sync_state: queue multiple settings change
- tts_allcaps_beep: queue caps beep change


## Supported Embeddings

- [{voice Foo}] - queue switch to voice best attempt (default fallback)
- [[pmod ##]] - queue +## pitch modification + by default, can be + or - 
