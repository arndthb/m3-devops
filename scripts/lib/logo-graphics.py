#!/usr/bin/env python3
"""Render the complete m³ logo as a transparent PNG via Kitty graphics.

Pure Python standard library. Image dimensions track terminal cell dimensions.
"""
import base64
import os
import struct
import sys
import zlib

# Five-row lettermark from the existing terminal banner, redrawn in pixels.
M = (
    "11000000011",
    "11100000111",
    "11010010111",
    "11001100111",
    "11000000011",
)
THREE = ("111", "001", "111", "001", "111")
SCALE = 7
W, H = 17 * SCALE, 9 * SCALE
ON = (105, 255, 161, 255)
OFF = (0, 0, 0, 0)
rgba = bytearray()
for y in range(H):
    rgba.append(0)  # PNG filter type: None
    for x in range(W):
        gx, gy = x // SCALE, y // SCALE
        m = 0 <= gy < 9 and 0 <= gx < 11 and M[min(4, gy * 5 // 9)][gx] == "1"
        three = 12 <= gx < 15 and 0 <= gy < 5 and THREE[gy][gx - 12] == "1"
        rgba.extend(ON if (m or three) else OFF)

def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

png = (b"\x89PNG\r\n\x1a\n" +
       chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)) +
       chunk(b"IDAT", zlib.compress(rgba)) + chunk(b"IEND", b""))
payload = base64.b64encode(png).decode("ascii")
# Display image over the left side of the existing header; retain text fallback
# in non-Kitty terminals. Use a unique image id and replace it on redraw.
sys.stdout.write("\x1b7\x1b[1;3H\x1b_Ga=T,f=100,i=733,c=15,r=5,q=2;" +
                 payload + "\x1b\\\x1b8")
