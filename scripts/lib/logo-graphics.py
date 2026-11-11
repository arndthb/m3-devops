#!/usr/bin/env python3
"""Render the complete m³ logo as transparent pixel art via Kitty graphics.

No third-party dependencies. The logo has a subtle 3D outline and a raised
superscript 3, one quarter the height of the M. Use --png for offline preview.
"""
import base64
import struct
import sys
import zlib

W, H = 180, 100
pixels = bytearray(W * H * 4)

def pixel(x, y, color):
    if 0 <= x < W and 0 <= y < H:
        i = (y * W + x) * 4
        pixels[i:i + 4] = bytes(color)

def inside(x, y, poly):
    result = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            result = not result
        j = i
    return result

def polygon(poly, color, dx=0, dy=0):
    poly = [(x + dx, y + dy) for x, y in poly]
    for y in range(max(0, min(p[1] for p in poly)), min(H, max(p[1] for p in poly) + 1)):
        for x in range(max(0, min(p[0] for p in poly)), min(W, max(p[0] for p in poly) + 1)):
            if inside(x + 0.5, y + 0.5, poly):
                pixel(x, y, color)

# Angular M with inset V and two pillars, following the original lettermark.
M = [(9, 7), (35, 7), (54, 42), (73, 7), (100, 7),
     (100, 90), (76, 90), (76, 45), (61, 72), (47, 72),
     (33, 45), (33, 90), (9, 90)]
polygon(M, (30, 89, 64, 255), 6, 7)       # dark 3D shadow
polygon(M, (91, 255, 158, 255), 4, 5)     # bright outline
polygon(M, (13, 44, 37, 255), 1, 2)       # narrow dark inset
polygon(M, (106, 252, 166, 255))         # green face

# Raised 3: 5 x 7 bitmap, 3px per dot, about one quarter of M's height.
THREE = ("11111", "00001", "00001", "01111", "00001", "00001", "11111")
for gy, row in enumerate(THREE):
    for gx, value in enumerate(row):
        if value == "1":
            for py in range(3):
                for px in range(3):
                    pixel(122 + gx * 3 + px, 8 + gy * 3 + py, (122, 255, 173, 255))

def chunk(kind, data):
    return (struct.pack(">I", len(data)) + kind + data +
            struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))

scanlines = bytearray()
for y in range(H):
    scanlines.append(0)
    scanlines.extend(pixels[y * W * 4:(y + 1) * W * 4])
png = (b"\x89PNG\r\n\x1a\n" +
       chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)) +
       chunk(b"IDAT", zlib.compress(scanlines)) + chunk(b"IEND", b""))
if "--png" in sys.argv:
    sys.stdout.buffer.write(png)
else:
    payload = base64.b64encode(png).decode("ascii")
    # Same 15x5-cell area as the original header; replace on redraw.
    sys.stdout.write("\x1b7\x1b[1;3H\x1b_Ga=T,f=100,i=733,c=15,r=5,q=2;" +
                     payload + "\x1b\\\x1b8")
