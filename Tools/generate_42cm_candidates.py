#!/usr/bin/env python3
"""Generate diagnostic animations for the 42 cm / 224 LED hologram fan.

The format constants are independently verified against the known-good files in
this project.  Each frame contains 2,700 angular samples, 112 radial RGB pixels
packed into 42 one-bit bytes per sample, and 1,288 zero padding bytes.
"""

from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


RAYS = 2700
RADIAL_LEDS = 112
BYTES_PER_RAY = 42
PAYLOAD_SIZE = RAYS * BYTES_PER_RAY
FRAME_PADDING = 1288
FRAME_SIZE = PAYLOAD_SIZE + FRAME_PADDING
CANVAS_SIZE = 450

# Bit positions for eight adjacent radial LEDs. The physical data is stored in
# 24-bit, reversed groups, with RGB bits interleaved in the controller's order.
RED_BITS = (16, 19, 22, 9, 12, 15, 2, 5)
GREEN_BITS = (17, 20, 23, 10, 13, 0, 3, 6)
BLUE_BITS = (18, 21, 8, 11, 14, 1, 4, 7)


def header_length(path: Path) -> int:
    """The known-good classic files are header + integral frame blocks."""
    return path.stat().st_size % FRAME_SIZE


def read_header(path: Path) -> bytes:
    size = header_length(path)
    if not (4096 <= size < FRAME_SIZE):
        raise ValueError(f"{path.name}: implausible classic header size {size}")
    with path.open("rb") as stream:
        return stream.read(size)


def legacy_header() -> bytes:
    """Deterministic version of the public legacy 4 KiB MP4 header."""
    rng = random.Random(0xF142)
    return bytes((0, 0, 0, 1, 0x18)) + bytes(
        rng.randrange(256) for _ in range(4096 - 5)
    )


def diagnostic_image(label: str, tick: int) -> Image.Image:
    """A high-contrast chart that exposes channel, rotation, and mirroring errors."""
    image = Image.new("RGB", (CANVAS_SIZE, CANVAS_SIZE), "black")
    draw = ImageDraw.Draw(image)
    center = CANVAS_SIZE // 2
    radius = center - 12

    # Colored arcs identify channel order without relying on text orientation.
    draw.arc((12, 12, CANVAS_SIZE - 12, CANVAS_SIZE - 12), 200, 300,
             fill=(255, 0, 0), width=28)
    draw.arc((12, 12, CANVAS_SIZE - 12, CANVAS_SIZE - 12), 320, 60,
             fill=(0, 255, 0), width=28)
    draw.arc((12, 12, CANVAS_SIZE - 12, CANVAS_SIZE - 12), 80, 180,
             fill=(0, 80, 255), width=28)

    # An asymmetric white L and moving yellow marker reveal orientation/rotation.
    draw.line((center - 92, center - 70, center - 92, center + 78),
              fill="white", width=18)
    draw.line((center - 92, center + 78, center + 38, center + 78),
              fill="white", width=18)
    angle = math.radians(tick * 36 - 90)
    marker_radius = radius - 47
    mx = center + marker_radius * math.cos(angle)
    my = center + marker_radius * math.sin(angle)
    draw.ellipse((mx - 16, my - 16, mx + 16, my + 16), fill=(255, 220, 0))

    font = ImageFont.load_default(size=52)
    draw.text((center + 10, center - 47), label, fill="white", font=font,
              stroke_width=2, stroke_fill="black")
    return image


def dither_on(column: int, ray: int, value: int) -> bool:
    # A 2x12 ordered threshold pattern preserves brightness on one-bit LEDs.
    level = max(0, min(12, round(value * 12 / 255)))
    offset = 6 if column & 1 else 0
    return ((ray + offset) % 12) < level


def bit_columns(led: int) -> tuple[int, int, int]:
    base = RADIAL_LEDS * 3 - 24 - (led // 8) * 24
    slot = led % 8
    return (
        base + RED_BITS[slot],
        base + GREEN_BITS[slot],
        base + BLUE_BITS[slot],
    )


def encode_frame(image: Image.Image, reverse_rotation: bool = False) -> bytes:
    pixels = image.load()
    center = (CANVAS_SIZE - 1) / 2
    radial_step = (CANVAS_SIZE - 1) / (RADIAL_LEDS * 2 - 1)
    output = bytearray(PAYLOAD_SIZE)

    for ray in range(RAYS):
        direction = ray if reverse_rotation else RAYS - ray
        angle = math.tau * direction / RAYS
        cos_angle, sin_angle = math.cos(angle), math.sin(angle)
        row_start = ray * BYTES_PER_RAY

        for led in range(RADIAL_LEDS):
            radius = (led + 0.5) * radial_step
            x = max(0, min(CANVAS_SIZE - 1, round(center + radius * cos_angle)))
            y = max(0, min(CANVAS_SIZE - 1, round(center + radius * sin_angle)))
            red, green, blue = pixels[x, y]
            for column, value in zip(bit_columns(led), (red, green, blue)):
                if dither_on(column, ray, value):
                    output[row_start + column // 8] |= 1 << (column % 8)

    output.extend(bytes(FRAME_PADDING))
    assert len(output) == FRAME_SIZE
    return bytes(output)


def write_animation(path: Path, header: bytes, frames: list[bytes], count: int) -> None:
    with path.open("wb") as stream:
        stream.write(header)
        for index in range(count):
            stream.write(frames[index % len(frames)])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    project = args.project.resolve()
    output = project / "hardware-tests" / "42cm"
    output.mkdir(parents=True, exist_ok=True)

    convesio = project / "convesio-logo.bin"
    ar15 = project / "228-ar15a.bin"
    convesio_header = read_header(convesio)
    ar15_header = read_header(ar15)
    convesio_count = (convesio.stat().st_size - len(convesio_header)) // FRAME_SIZE
    ar15_count = (ar15.stat().st_size - len(ar15_header)) // FRAME_SIZE

    specifications = (
        ("01-best-match", "1", convesio_header, False, convesio_count),
        ("02-reverse-rotation", "2", ar15_header, True, ar15_count),
        ("03-legacy-header", "3", legacy_header(), False, convesio_count),
    )

    for stem, label, header, reverse, count in specifications:
        print(f"Encoding {stem} ({count} frames, header {len(header)} bytes)...")
        images = [diagnostic_image(label, tick) for tick in range(10)]
        images[0].save(output / f"{stem}-preview.png")
        frames = [encode_frame(image, reverse) for image in images]
        write_animation(output / f"{stem}.bin", header, frames, count)

    print(f"Wrote candidates to {output}")


if __name__ == "__main__":
    main()
