# Halosmith

A native macOS app for preparing video for holographic fan displays.

## Current profiles

- **F-mini 11:** Type-7 `.bin` export for the 48-LED fan. Source frames are preserved at their native frame rate and encoded as 300 polar rays with five RGB bit planes per frame.
- **Large fan (42 cm / F1):** Hardware-verified `.bin` export for the 224-LED fan. Video is sampled at 10 fps, aspect-filled from the adjustable 1:1 preview, converted into 2,700 polar rays per frame, and written with the generic header accepted by the physical unit.

## Run

Run `./script/build_and_run.sh`.

Requires macOS 14 or later and matching Apple Command Line Tools.
