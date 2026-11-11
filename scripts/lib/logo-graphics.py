#!/usr/bin/env python3
"""Render a tiny raised 3 using the Kitty terminal graphics protocol.

No external Python packages. Only called for known Kitty-capable terminals.
"""
import base64
import struct
import sys
import zlib

PATTERN = ("11111", "00001", "00001", "01111", "00001", "00001", "11111")
SCALE = 3
WIDTH, HEIGHT = 5 * SCALE, 7 * SCALE
COLOR = (104, 255, 158, 255)
pixels = bytearray()
for y in range(HEIGHT):
    pixels.append(0)
    for x in range(WIDTH):
        active = PATTERN[y // SCALE][x // SCALE] == "1"
        pixels.extend(COLOR if active else (0, 0, 0, 0))

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)

png = (b"\x89PNG\r\n\x1a\n" +
       chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 6, 0, 0, 0)) +
       chunk(b"IDAT", zlib.compress(bytes(pixels))) +
       chunk(b"IEND", b""))
payload = base64.b64encode(png).decode("ascii")
sys.stdout.write("\x1b7\x1b[1;17H\x1b_Gf=100,a=T,c=3,r=2,q=2;" + payload + "\x1b\\\x1b8")
