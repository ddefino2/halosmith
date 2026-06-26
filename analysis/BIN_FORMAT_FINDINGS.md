# BIN format findings

## Conclusion

The project contains two different 5DDisplayer formats. They must not share an
encoder profile.

### 42 cm fan / F1 / 224 LEDs

The two accepted large-fan samples use the classic 224-LED format:

| File | Header | Frames | Frame size |
| --- | ---: | ---: | ---: |
| `convesio-logo.bin` | 4,244 bytes | 120 | 114,688 bytes |
| `228-ar15a.bin` | 4,920 bytes | 164 | 114,688 bytes |

Every frame is:

- 2,700 angular rays
- 112 radial RGB positions (224 physical LEDs across the diameter)
- 42 packed one-bit bytes per ray (`112 × 3 / 8`)
- 113,400 bytes of image data (`2,700 × 42`)
- 1,288 zero padding bytes

The frame packing and radial bit order also agree with the independently
reverse-engineered open-source 224-LED implementation:
<https://github.com/jnweiger/led-hologram-propeller>

### F-mini 11 / 48 LEDs

The three newly supplied accepted files are a newer type-7 container:

| File | Prefix | Header | Frames | Frame size | Final padding |
| --- | --- | ---: | ---: | ---: | ---: |
| `06Christmas.bin` | `EE 37` | 812 bytes | 360 | 28,600 bytes | 100,000 zeros |
| `07Sing.bin` | `EE 37` | 268 bytes | 420 | 28,600 bytes | 100,000 zeros |
| `08Father Christmas.bin` | `EE 37` | 108 bytes | 200 | 28,600 bytes | 100,000 zeros |

Decompiling the bundled manufacturer's `5DDisplayer.exe` identifies internal
type 7 as 300 angular rows, 48 radial LEDs, five bit planes, RGB, and polar
rotation. Its computed frame size is exactly:

`300 × ceil(48 × 3 / 8) × 5 + 1,600 = 28,600 bytes`

The executable's equipment list places F-mini 11 at that type index. The `37`
byte in the file prefix is ASCII `7`, which independently agrees with the type.

Eight additional accepted files in `f-mini-11-clips` confirm the same container
shape. Across all eleven samples:

- the header is variable-length and starts with `EE 37`;
- every body is an integral number of 28,600-byte frames;
- every file ends with exactly 100,000 zero bytes;
- each frame contains 300 angular rows of five 18-byte RGB bit planes, followed
  by a 1,600-byte audio interval;
- plane 0 is the most significant bit, and each plane packs 48 RGB pixels in
  reversed groups of eight LEDs using the controller's 24-bit RGB wiring order.

Decoding `03dskull-ho.bin` with this layout reconstructs the matching cyan skull
animation from `3dskull-holo.mp4`; alternate plane-major and LSB-first layouts
produce incoherent output. The production F-mini 11 profile now implements this
type-7 encoder at the source video's native frame rate and uses the shortest
supplied accepted header (108 bytes) plus the confirmed 100,000-byte trailer.

The 1,600-byte suffix is zero in some clips without audio and resembles unsigned
8-bit PCM centered on `0x80` in clips with audio. Halosmith currently emits
manufacturer-style `0x80` silence; audio preservation can be added independently
without changing the recovered image encoding.

## Hardware tests

The candidates in `hardware-tests/42cm` intentionally vary only the uncertain
compatibility details:

1. `01-best-match.bin`: confirmed packing, canonical rotation, and an accepted
   header copied from `convesio-logo.bin`.
2. `02-reverse-rotation.bin`: confirmed packing, opposite angular direction,
   and the other accepted header family from `228-ar15a.bin`.
3. `03-legacy-header.bin`: confirmed packing and the documented generic 4 KiB
   legacy header.

Candidate 1 is the expected winner. Candidate 2 tests whether the image direction
needs reversing. Candidate 3 tests whether generated files can use a generic
header instead of borrowing a header from an existing animation.

## Hardware result — 2026-06-21

Photos and a continuous video in `test-encoding` confirm:

- All three generated BIN files are accepted and played by the 42 cm fan.
- Candidate 1 has correct RGB channels and correct orientation.
- Candidate 2 has correct RGB channels but is mirrored across the horizontal
  axis. Reversing the angular samples is therefore incorrect for this unit.
- Candidate 3 has correct RGB channels and correct orientation. The fan accepts
  the generated generic 4 KiB legacy header, so exporting does not require a
  header copied from an existing BIN file.
- The moving yellow marker animates, confirming that consecutive frame blocks
  are advancing normally.

The production 42 cm profile uses candidate 3's generic header and candidate
1/3's canonical angular direction. The F-mini 11 encoder remains a separate
profile and uses its confirmed type-7 parameters.
