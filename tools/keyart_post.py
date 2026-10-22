#!/usr/bin/env python3
"""Tratamento da arte de carregamento: contraste quente, vinheta e escurecido embaixo (onde fica a barra).
Uso: python3 tools/keyart_post.py entrada.png  ->  art/loading.jpg"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
im = Image.open(sys.argv[1]).convert("RGB").resize((1280, 720), Image.LANCZOS)
a = np.asarray(im).astype(np.float32) / 255.0
h, w, _ = a.shape
# curva S + leve tom quente nas luzes e frio nas sombras
a = a * a * (3 - 2 * a) * 0.6 + a * 0.4
lum = a.mean(axis=2, keepdims=True)
a = a + (lum - 0.5) * np.array([0.06, 0.0, -0.06])
# brilho difuso (bloom barato)
glow = np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(18))).astype(np.float32) / 255.0
a = 1 - (1 - a) * (1 - np.clip(glow - 0.55, 0, 1) * 0.6)
# vinheta + faixa escura embaixo
yy, xx = np.mgrid[0:h, 0:w]
d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h * 0.45) / (h / 2)) ** 2)
a *= (1 - np.clip(d - 0.55, 0, 1) * 0.7)[..., None]
bot = np.clip((yy - h * 0.62) / (h * 0.38), 0, 1)
a *= (1 - bot * 0.75)[..., None]
os.makedirs(os.path.join(ROOT, "art"), exist_ok=True)
Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(os.path.join(ROOT, "art", "loading.jpg"), quality=86)
print("ok")
