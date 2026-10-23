#!/usr/bin/env python3
"""Cartões de folhagem das árvores (models/trees/leaves.png, 1024x1024 RGBA, 2x2 cartões):
  0 = cacho de folhas largas (denso)    1 = galho com folhas (ralo)
  2 = ramo de pinheiro (agulhas)        3 = moita (folhas pequenas, bem fechado)
As folhas vêm da textura "tree_small_02_leaves" do Poly Haven (CC0): cada folha é recortada do
fundo preto e as folhas são espalhadas em cima de galhinhos desenhados aqui.
Uso: python3 tools/make_leaf_cards.py <tree_small_02_leaves_diff_1k.jpg>
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
random.seed(7)
rs = np.random.default_rng(7)

src = Image.open(sys.argv[1]).convert("RGB")
W, H = src.size
a = np.asarray(src).astype(np.float32) / 255.0
lum = a @ np.array([0.3, 0.59, 0.11])
mask = lum > 0.07
mask[:, int(W * 0.7):] = False      # o lado direito da textura é borrado
lab, n = ndimage.label(ndimage.binary_opening(mask, iterations=2))
sprites = []
for i, sl in enumerate(ndimage.find_objects(lab)):
    if sl is None:
        continue
    h = sl[0].stop - sl[0].start
    w = sl[1].stop - sl[1].start
    area = int((lab[sl] == i + 1).sum())
    # só folhas inteiras (descarta pedaço de galho, comprido e fino)
    if area < 1500 or area > 40000 or max(w, h) > 260 or min(w, h) < 18 or max(w, h) > 2.6 * min(w, h) or area < 0.35 * w * h:
        continue
    rgb = np.asarray(src)[sl]
    al = ((lab[sl] == i + 1) * 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([rgb, al]), "RGBA")
    sprites.append(im)
print("folhas recortadas:", len(sprites))


def twig(dr, x0, y0, ang, length, width, col, depth):
    x1 = x0 + math.cos(ang) * length
    y1 = y0 - math.sin(ang) * length
    dr.line([(x0, y0), (x1, y1)], fill=col, width=max(1, int(width)))
    pts = [(x1, y1)]
    if depth > 0:
        for k in range(random.randint(2, 3)):
            t = random.uniform(0.35, 1.0)
            bx = x0 + (x1 - x0) * t
            by = y0 + (y1 - y0) * t
            pts += twig(dr, bx, by, ang + random.uniform(-0.9, 0.9), length * random.uniform(0.45, 0.7), width * 0.6, col, depth - 1)
    return pts


def leaf_card(size, n_leaves, leaf_sc, spread, tint, seed):
    random.seed(seed)
    card = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dr = ImageDraw.Draw(card)
    tips = twig(dr, size * 0.5, size * 0.8, math.pi / 2 + random.uniform(-0.15, 0.15), size * 0.36, size * 0.014, (78, 62, 44, 255), 3)
    for k in range(n_leaves):
        sp = random.choice(sprites)
        sc = leaf_sc * random.uniform(0.7, 1.15) * size / 512.0
        sp = sp.resize((max(4, int(sp.width * sc)), max(4, int(sp.height * sc))), Image.LANCZOS)
        tx, ty = random.choice(tips)
        tx += random.gauss(0, size * spread)
        ty += random.gauss(0, size * spread)
        ang = math.degrees(math.atan2(size * 0.6 - ty, tx - size * 0.5)) - 90 + random.uniform(-50, 50)
        sp = sp.rotate(ang, expand=True, resample=Image.BICUBIC)
        # folhas de trás mais escuras, as da frente mais claras
        f = 0.62 + 0.5 * k / n_leaves
        r, g, b, al = sp.split()
        rgb = Image.merge("RGB", (r, g, b))
        arr = np.asarray(rgb).astype(np.float32) * f * np.array(tint)
        sp = Image.merge("RGBA", (*Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).split(), al))
        x = int(tx - sp.width / 2)
        y = int(ty - sp.height / 2)
        card.alpha_composite(sp, (max(0, min(size - sp.width, x)), max(0, min(size - sp.height, y))))
    return card


def pine_card(size, seed):
    random.seed(seed)
    card = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dr = ImageDraw.Draw(card)
    # ramo descendo um pouco, com raminhos dos lados e agulhas finas
    axes = []
    x0, y0 = size * 0.5, size * 0.95
    for k in range(14):
        t = k / 13.0
        x1 = size * 0.5 + random.uniform(-8, 8)
        y1 = size * (0.95 - 0.88 * t)
        axes.append((x1, y1))
    for i in range(len(axes) - 1):
        dr.line([axes[i], axes[i + 1]], fill=(70, 55, 40, 255), width=int(size * 0.012))
    for (cx, cy) in axes:
        for s in (-1, 1):
            L = size * random.uniform(0.3, 0.46) * (1.0 - abs(cy / size - 0.5) * 0.7)
            ang = math.radians(random.uniform(20, 45))
            ex, ey = cx + s * math.cos(ang) * L * 0.62, cy - math.sin(ang) * L * 0.5
            dr.line([(cx, cy), (ex, ey)], fill=(70, 55, 40, 255), width=max(1, int(size * 0.006)))
            for j in range(45):
                t = random.random()
                px, py = cx + (ex - cx) * t, cy + (ey - cy) * t
                na = random.uniform(0, math.tau)
                nl = size * random.uniform(0.04, 0.075)
                g = random.randint(80, 135)
                dr.line([(px, py), (px + math.cos(na) * nl, py + math.sin(na) * nl)], fill=(int(g * 0.45), g, int(g * 0.4), 255), width=max(1, int(size * 0.005)))
    return card


S = 512
atlas = Image.new("RGBA", (S * 2, S * 2), (0, 0, 0, 0))
atlas.alpha_composite(leaf_card(S, 140, 0.55, 0.06, (1.0, 1.0, 0.95), 1), (0, 0))
atlas.alpha_composite(leaf_card(S, 70, 0.6, 0.05, (1.05, 1.02, 0.9), 2), (S, 0))
atlas.alpha_composite(pine_card(S, 3), (0, S))
atlas.alpha_composite(leaf_card(S, 190, 0.38, 0.09, (0.92, 0.98, 0.85), 4), (S, S))
# cor por baixo do transparente = média das folhas (sem borda preta quando o celular reduz a textura)
arr = np.asarray(atlas).astype(np.float32)
al = arr[..., 3:4] / 255.0
mean = (arr[..., :3] * al).sum((0, 1)) / max(al.sum(), 1)
fill = Image.new("RGB", atlas.size, tuple(int(c) for c in mean))
rgb = Image.composite(atlas.convert("RGB"), fill, atlas.split()[3])
blur = rgb.filter(ImageFilter.GaussianBlur(6))
rgb = Image.composite(rgb, blur, atlas.split()[3].point(lambda v: 255 if v > 100 else 0))
out = Image.merge("RGBA", (*rgb.split(), atlas.split()[3].point(lambda v: 255 if v > 110 else 0)))
os.makedirs(os.path.join(ROOT, "models", "trees"), exist_ok=True)
out.save(os.path.join(ROOT, "models", "trees", "leaves.png"))
print("salvo models/trees/leaves.png")
