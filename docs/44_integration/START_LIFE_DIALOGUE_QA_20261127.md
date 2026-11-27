# Start life, speech and runtime QA follow-up

- Previous real export contained 154 expected distinct lines; 114 were absent from manifest; 40 matched text, speaker, hashes and ASR metadata, but old checker incorrectly demanded keys instead of actual forced-alignment segments. New audit uses shared segment validator, exact identity, duration, bounded indices and 16.7ms onset.
- Godot export includes I-01 contact lines and actual village idle/opening lines. Voice workflow now consumes that export, includes all 12 currently missing speakers, and supersedes obsolete candidate runs. Generated candidates still require listening/import checks and explicit staging. No claim of new audio output.
- Runtime rejects malformed mouth tracks rather than driving wrong facial movements. Subtitles and audio still retain existing clock.
- Dedicated parent model gate remains mandatory in dedicated anatomy workflow; generic civilian rebuild review checks age morphs without falsely treating it as dedicated generation.
- Verified Sextus/Vibius derivative staging updates the city catalogue only after the four actual GLBs pass checks.
- Weather regression corrected to use a real previous clock second, not forbidden negative advance. Wetness continuous across block boundaries, and village decisions sample the same five-minute clock as presentation.
