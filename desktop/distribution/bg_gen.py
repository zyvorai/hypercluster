#!/usr/bin/env python3
"""
Pure Python stdlib PNG generator for Hypercluster macOS installer background.
No PIL/Pillow or external deps — only struct and zlib.
Output: 1280x800 8-bit RGB PNG
"""
import struct
import zlib
import math

WIDTH = 1280
HEIGHT = 800

# Brand colors (as float 0-1)
BG_BASE    = (0x05 / 255, 0x05 / 255, 0x08 / 255)   # #050508
BG_BAND_TL = (0x12 / 255, 0x0b / 255, 0x08 / 255)   # #120b08  (top-left band origin)
ORANGE     = (0xf0 / 255, 0x58 / 255, 0x3a / 255)   # #f0583a
VIOLET     = (0xa7 / 255, 0x8b / 255, 0xfa / 255)   # #a78bfa

# Glow parameters
ORANGE_CX, ORANGE_CY, ORANGE_R   = 200.0, 160.0, 280.0
VIOLET_CX, VIOLET_CY, VIOLET_R   = 1100.0, 620.0, 200.0
ORANGE_ALPHA = 0.15
VIOLET_ALPHA = 0.10

# Diagonal band: how far along the main diagonal (normalised 0-1) each pixel is
DIAG_LEN = math.sqrt(WIDTH * WIDTH + HEIGHT * HEIGHT)  # full diagonal length


def cosq_falloff(dist, radius):
    """Smooth cos² falloff: 1 at dist=0, 0 at dist>=radius, no banding."""
    if dist >= radius:
        return 0.0
    t = dist / radius          # 0 → 1
    c = math.cos(t * math.pi * 0.5)   # cos(0)=1, cos(π/2)=0
    return c * c               # cos²


def make_pixel(x, y):
    """Return (r, g, b) as 0–255 ints for pixel (x, y)."""
    # --- 1. Diagonal band blend (top-left lighter, bottom-right darker) ---
    # Project (x,y) onto the main diagonal direction
    proj = (x * WIDTH + y * HEIGHT) / DIAG_LEN    # 0 at corner (0,0), DIAG_LEN at (W,H)
    t_diag = proj / DIAG_LEN                      # normalised 0-1

    # Smoothstep to avoid linear banding
    t_s = t_diag * t_diag * (3.0 - 2.0 * t_diag)

    # Blend from BG_BAND_TL (t=0) to BG_BASE (t=1)
    base_r = BG_BAND_TL[0] + (BG_BASE[0] - BG_BAND_TL[0]) * t_s
    base_g = BG_BAND_TL[1] + (BG_BASE[1] - BG_BAND_TL[1]) * t_s
    base_b = BG_BAND_TL[2] + (BG_BASE[2] - BG_BAND_TL[2]) * t_s

    # --- 2. Orange radial glow ---
    d_o = math.sqrt((x - ORANGE_CX) ** 2 + (y - ORANGE_CY) ** 2)
    fo  = cosq_falloff(d_o, ORANGE_R)
    a_o = fo * ORANGE_ALPHA

    # --- 3. Violet radial glow ---
    d_v = math.sqrt((x - VIOLET_CX) ** 2 + (y - VIOLET_CY) ** 2)
    fv  = cosq_falloff(d_v, VIOLET_R)
    a_v = fv * VIOLET_ALPHA

    # --- 4. Composite: base + orange glow + violet glow (additive blend) ---
    r = base_r * (1.0 - a_o) + ORANGE[0] * a_o
    g = base_g * (1.0 - a_o) + ORANGE[1] * a_o
    b = base_b * (1.0 - a_o) + ORANGE[2] * a_o

    r = r * (1.0 - a_v) + VIOLET[0] * a_v
    g = g * (1.0 - a_v) + VIOLET[1] * a_v
    b = b * (1.0 - a_v) + VIOLET[2] * a_v

    # Clamp and convert to 8-bit
    return (
        min(255, max(0, round(r * 255))),
        min(255, max(0, round(g * 255))),
        min(255, max(0, round(b * 255))),
    )


def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    length = struct.pack('>I', len(data))
    crc    = struct.pack('>I', zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
    return length + chunk_type + data + crc


def build_png(width, height):
    # PNG signature
    sig = b'\x89PNG\r\n\x1a\n'

    # IHDR: width, height, bit_depth=8, color_type=2 (RGB), compression=0,
    #        filter=0, interlace=0
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr = png_chunk(b'IHDR', ihdr_data)

    # Build raw scanlines: filter byte (0 = None) + RGB pixels
    # Accumulate into a bytearray for efficiency
    raw = bytearray()
    for y in range(height):
        raw.append(0)   # filter type = None
        for x in range(width):
            r, g, b = make_pixel(x, y)
            raw.append(r)
            raw.append(g)
            raw.append(b)
        if (y + 1) % 100 == 0:
            print(f"  row {y+1}/{height}")

    # Compress with zlib (level 6 — good compression, not too slow)
    compressed = zlib.compress(bytes(raw), 6)
    idat = png_chunk(b'IDAT', compressed)

    # IEND
    iend = png_chunk(b'IEND', b'')

    return sig + ihdr + idat + iend


def main():
    out_path = '/Users/ssahani/tt/hypercluster/desktop/distribution/bg.png'
    print(f"Generating {WIDTH}x{HEIGHT} PNG …")
    data = build_png(WIDTH, HEIGHT)
    with open(out_path, 'wb') as f:
        f.write(data)
    print(f"Written {len(data):,} bytes → {out_path}")


if __name__ == '__main__':
    main()
