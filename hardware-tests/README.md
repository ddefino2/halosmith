# Hologram fan hardware tests

These files are diagnostic animations, not final customer media. They use a
bright asymmetric chart to reveal rotation, mirroring, and RGB-channel errors.

## 42 cm fan

Test the files in `42cm` in numerical order:

1. `01-best-match.bin` — confirmed frame packing and a header copied from the
   known-good `convesio-logo.bin`. This is the highest-confidence candidate.
2. `02-reverse-rotation.bin` — the same packing with the angular sampling
   reversed and the header family from `228-ar15a.bin`.
3. `03-legacy-header.bin` — confirmed frame packing with the commonly documented
   4 KiB legacy header.

Record for each file whether it appears in the fan's file list, starts playing,
and displays the red/green/blue arcs, white L, number, and moving yellow dot.

### Result

Testing on 2026-06-21 confirmed that all three files load. Candidates 1 and 3
have correct color and orientation; candidate 2 is flipped top-to-bottom. The
production choice is candidate 3's generated legacy header with candidate 1/3's
canonical angular direction.

Back up the original memory card first. Copy only one test file at a time, eject
the card cleanly, and switch power off before inserting or removing it.

## Regenerating

Run with the bundled Python environment (Pillow is required):

```sh
/Users/daviddefino/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 Tools/generate_42cm_candidates.py
```
