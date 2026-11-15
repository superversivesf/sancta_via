#!/usr/bin/env python3
"""Regenerates the two new app icons from the house icon.

The house convention (navy field, gold Latin cross, white path) is reused
pixel-for-pixel from sancta_via_novena_companion/assets/app_icon.png; this
script erases that app's badge (candle + rays) and draws each new app's
badge: an 8-point star + halo (saints) and an open book of hours
(devotionals). Output: both apps' assets/app_icon.png at 1024x1024.

Usage: python3 tool/make_app_icons.py  (from the repo root)
"""
from PIL import Image, ImageDraw
import math

NAVY = (0, 31, 62)
EDGE = [(548, 700), (552, 710), (576, 700), (600, 685), (624, 668),
        (648, 650), (672, 636), (700, 620), (760, 560), (840, 540),
        (940, 540), (1024, 540)]


def erase_badge_strong(im):
    """Erase all non-navy pixels right of the path's outer edge."""
    w, h = im.size
    px = im.load()
    ei = 0
    for y in range(448, h):
        while ei < len(EDGE) - 1 and EDGE[ei + 1][0] <= y:
            ei += 1
        for x in range(EDGE[ei][1] + 12, w):
            p = px[x, y]
            if math.dist(p, NAVY) >= 4:
                px[x, y] = NAVY
    return im


def draw_saints(big):
    d = ImageDraw.Draw(big)
    cx, cy = 830*4, 715*4
    R, r = 150*4, 92*4
    pts = []
    for k in range(16):
        ang = -math.pi/2 + k*math.pi/8
        rad = R if k % 2 == 0 else r
        pts.append((cx + rad*math.cos(ang), cy + rad*math.sin(ang)))
    d.polygon(pts, fill=(235, 234, 230))
    d.ellipse([cx-48*4, cy-48*4, cx+48*4, cy+48*4], outline=(209, 170, 87),
              width=20*4)


def draw_devotionals(big):
    d = ImageDraw.Draw(big)
    cx, cy = 812*4, 640*4
    w2, h2 = 150*4, 200*4
    left = [(cx-w2, cy), (cx, cy+34), (cx, cy+h2-20), (cx-w2, cy+h2-10)]
    right = [(cx, cy+34), (cx+w2, cy), (cx+w2, cy+h2-10), (cx, cy+h2-20)]
    d.polygon(left, fill=(235, 234, 230))
    d.polygon(right, fill=(235, 234, 230))
    d.polygon([(cx+18*4, cy+40), (cx+34*4, cy+46), (cx+34*4, cy+100),
               (cx+18*4, cy+94)], fill=(209, 170, 87))
    d.rectangle([cx-w2, cy+h2-4, cx+w2, cy+h2-4+16], fill=(209, 170, 87))


if __name__ == '__main__':
    base = erase_badge_strong(
        Image.open('sancta_via_novena_companion/assets/app_icon.png')
        .convert('RGB'))
    big = base.resize((4096, 4096), Image.LANCZOS)
    draw_saints(big)
    big.resize((1024, 1024), Image.LANCZOS).save(
        'sancta_via_saint_companion/assets/app_icon.png')
    big = base.resize((4096, 4096), Image.LANCZOS)
    draw_devotionals(big)
    big.resize((1024, 1024), Image.LANCZOS).save(
        'sancta_via_devotionals/assets/app_icon.png')
    print('icons written')
