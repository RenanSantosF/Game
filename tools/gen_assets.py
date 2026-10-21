#!/usr/bin/env python3
"""Gera as texturas e os sons do jogo (tudo procedural, sem arquivos de terceiros).

Uso:  python3 tools/gen_assets.py
Saída: textures/atlas.png (4x4 camadas de 512 px, importado como Texture2DArray)
       sounds/*.wav
"""
import math
import os
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 512
rng = np.random.default_rng(2018)


# ---------------------------------------------------------------- ruído

def noise(cells, seed, size=S):
    """Ruído suave e repetível nas bordas (tile)."""
    r = np.random.default_rng(seed)
    g = r.random((cells, cells)).astype(np.float32)
    big = np.tile(g, (3, 3))
    im = Image.fromarray((big * 255).astype(np.uint8))
    im = im.resize((size * 3, size * 3), Image.BICUBIC)
    a = np.asarray(im, dtype=np.float32)[size:size * 2, size:size * 2] / 255.0
    return a


def fbm(seed, base=4, octaves=5, pers=0.55, size=S):
    acc = np.zeros((size, size), np.float32)
    amp = 1.0
    tot = 0.0
    c = base
    for o in range(octaves):
        acc += noise(c, seed + o * 17, size) * amp
        tot += amp
        amp *= pers
        c *= 2
    acc /= tot
    acc = (acc - acc.min()) / (acc.max() - acc.min() + 1e-6)
    return acc


def lerp(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return np.asarray(a, np.float32) * (1 - t) + np.asarray(b, np.float32) * t


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def wrap_draw(img, fn):
    """Desenha com repetição nas bordas pra textura continuar sem emenda."""
    big = Image.new("RGB", (S * 3, S * 3))
    for i in range(3):
        for j in range(3):
            big.paste(img, (i * S, j * S))
    d = ImageDraw.Draw(big)
    fn(d)
    # junta as 9 cópias desenhadas no centro
    out = np.asarray(big, np.float32)
    c = out[S:2 * S, S:2 * S].copy()
    return c


def strokes(img, n, length, width, colors, angle_spread=math.pi, angle0=-math.pi / 2, seed=0):
    r = np.random.default_rng(seed)
    pts = []
    for _ in range(n):
        x, y = r.random() * S, r.random() * S
        a = angle0 + (r.random() - 0.5) * angle_spread
        L = r.uniform(*length)
        col = colors[r.integers(len(colors))]
        k = r.uniform(0.8, 1.15)
        col = tuple(int(min(255, c * k)) for c in col)
        w = int(r.integers(width[0], width[1] + 1))
        pts.append((x, y, x + math.cos(a) * L, y + math.sin(a) * L, col, w))

    def fn(d):
        for (x0, y0, x1, y1, col, w) in pts:
            for ox in (0, S, 2 * S):
                for oy in (0, S, 2 * S):
                    d.line((x0 + ox, y0 + oy, x1 + ox, y1 + oy), fill=col, width=w)
    return wrap_draw(img, fn)


def blobs(img, n, rad, colors, seed=0, shade=True):
    r = np.random.default_rng(seed)
    items = []
    for _ in range(n):
        x, y = r.random() * S, r.random() * S
        rx = r.uniform(*rad)
        ry = rx * r.uniform(0.6, 1.0)
        col = colors[r.integers(len(colors))]
        items.append((x, y, rx, ry, col))

    def fn(d):
        for (x, y, rx, ry, col) in items:
            for ox in (0, S, 2 * S):
                for oy in (0, S, 2 * S):
                    X, Y = x + ox, y + oy
                    if shade:
                        dark = tuple(int(c * 0.55) for c in col)
                        d.ellipse((X - rx, Y - ry + rx * 0.25, X + rx, Y + ry + rx * 0.25), fill=dark)
                    d.ellipse((X - rx, Y - ry, X + rx, Y + ry), fill=col)
                    if shade:
                        hi = tuple(int(min(255, c * 1.25)) for c in col)
                        d.ellipse((X - rx * 0.5, Y - ry * 0.6, X + rx * 0.1, Y - ry * 0.1), fill=hi)
    return wrap_draw(img, fn)


def shade_mult(arr, m):
    return arr * m[..., None]


# ---------------------------------------------------------------- texturas

def tex_grass():
    n = fbm(1, 4)
    n2 = fbm(2, 16, 4)
    base = lerp((52, 70, 30), (98, 104, 50), n)
    base = lerp(base, (112, 100, 58), np.clip(fbm(3, 3) * 1.6 - 0.9, 0, 1))
    base = shade_mult(base, 0.8 + n2 * 0.35)
    img = to_img(base)
    cols = [(60, 86, 34), (78, 102, 40), (96, 112, 48), (122, 120, 62), (44, 64, 28), (140, 132, 74)]
    a = strokes(img, 14000, (5, 13), (1, 2), cols, angle_spread=1.6, seed=4)
    a = shade_mult(a, 0.85 + fbm(5, 32, 3) * 0.3)
    return a


def tex_dirt():
    n = fbm(10, 4)
    base = lerp((96, 76, 54), (142, 116, 84), n)
    base = shade_mult(base, 0.8 + fbm(11, 24, 4) * 0.35)
    img = to_img(base)
    a = blobs(img, 900, (1.5, 5.0), [(120, 108, 92), (90, 80, 70), (150, 135, 110), (110, 95, 75)], seed=12)
    cr = fbm(13, 8, 4)
    crack = np.clip(1 - np.abs(cr - 0.5) * 60, 0, 1) * 0.18
    a = shade_mult(a, 1 - crack)
    return a


def tex_rock():
    n = fbm(20, 4, 6)
    base = lerp((88, 86, 82), (150, 146, 138), n)
    y = np.linspace(0, 1, S, dtype=np.float32)[:, None]
    strata = 0.9 + 0.1 * np.sin((y * 9 + fbm(21, 3) * 2.5) * math.pi * 2)
    base = shade_mult(base, strata * (0.75 + fbm(22, 32, 3) * 0.4))
    cr = fbm(23, 6, 4)
    crack = np.clip(1 - np.abs(cr - 0.5) * 50, 0, 1) * 0.28
    base = shade_mult(base, 1 - crack)
    lich = np.clip(fbm(24, 10, 3) * 3 - 2.2, 0, 1)
    base = lerp(base, (118, 122, 80), lich * 0.6)
    return base


def tex_sand():
    n = fbm(30, 6)
    base = lerp((150, 132, 100), (182, 164, 128), n)
    base = shade_mult(base, 0.82 + rng.random((S, S)).astype(np.float32) * 0.3)
    img = to_img(base)
    return blobs(img, 700, (1.2, 3.5), [(130, 120, 105), (165, 150, 125), (110, 100, 90)], seed=31)


def tex_plaster():
    n = fbm(40, 3, 5, 0.6)
    base = lerp((196, 192, 182), (226, 222, 212), n)
    base = shade_mult(base, 0.93 + rng.random((S, S)).astype(np.float32) * 0.1)
    stain = np.clip(fbm(41, 4) * 2.2 - 1.3, 0, 1)
    base = lerp(base, (150, 142, 125), stain * 0.35)
    return base


def tex_brick():
    a = np.zeros((S, S, 3), np.float32)
    bh, bw = 32, 64
    r = np.random.default_rng(50)
    mort = np.array((150, 145, 135), np.float32)
    for row in range(S // bh):
        off = (bw // 2) * (row % 2)
        for col in range(-1, S // bw + 1):
            c = np.array((r.uniform(120, 165), r.uniform(55, 80), r.uniform(40, 58)), np.float32)
            x0 = col * bw + off
            y0 = row * bh
            for x in range(x0 + 2, x0 + bw - 2):
                xx = x % S
                a[y0 + 2:y0 + bh - 2, xx] = c
    mask = (a.sum(axis=2) == 0)
    a[mask] = mort
    a = shade_mult(a, 0.8 + fbm(51, 32, 3) * 0.35)
    return a


def tex_roof():
    a = np.zeros((S, S, 3), np.float32)
    th, tw = 42, 48
    r = np.random.default_rng(60)
    rows = S // th + 1
    for row in range(S // th + 1):
        off = (tw // 2) * (row % 2)
        for col in range(-1, S // tw + 1):
            c = np.array((r.uniform(125, 158), r.uniform(64, 82), r.uniform(48, 60)), np.float32)
            x0 = col * tw + off
            y0 = row * th
            for y in range(y0, min(y0 + th, S)):
                t = (y - y0) / th
                sh = 0.55 + 0.6 * math.sin(t * math.pi * 0.9 + 0.2)
                for x in range(x0 + 1, x0 + tw - 1):
                    u = (x - x0) / tw
                    cs = 0.8 + 0.3 * math.sin(u * math.pi)
                    a[y, x % S] = c * sh * cs
    a = shade_mult(a, 0.85 + fbm(61, 32, 3) * 0.25)
    a = lerp(a, (80, 78, 70), np.clip(fbm(62, 5) * 2 - 1.2, 0, 1) * 0.5)
    return a


def tex_wood():
    a = np.zeros((S, S, 3), np.float32)
    pw = 64
    r = np.random.default_rng(70)
    grain = noise(6, 71, S)
    gy = np.asarray(Image.fromarray((fbm(72, 32, 4) * 255).astype(np.uint8)).resize((S // 24, S)).resize((S, S)), np.float32) / 255
    for p in range(S // pw):
        c = np.array((r.uniform(105, 140), r.uniform(75, 95), r.uniform(48, 62)), np.float32)
        a[:, p * pw:(p + 1) * pw] = c
        a[:, p * pw:p * pw + 2] = c * 0.45
    g = np.sin((np.arange(S)[None, :] * 0.9 + gy * 6 + grain * 2)) * 0.5 + 0.5
    a = shade_mult(a, 0.78 + g * 0.22 + fbm(73, 24, 3) * 0.15)
    return a


def tex_metal():
    x = np.arange(S, dtype=np.float32)[None, :]
    ridge = 0.72 + 0.28 * np.sin(x / S * math.pi * 2 * 16)
    base = np.ones((S, S), np.float32)[..., None] * np.array((150, 154, 152), np.float32)
    base = shade_mult(base, ridge * (0.85 + fbm(80, 8, 4) * 0.2))
    rust = np.clip(fbm(81, 5, 5) * 2.4 - 1.4, 0, 1)
    base = lerp(base, (122, 72, 42), rust * 0.85)
    streak = np.asarray(Image.fromarray((fbm(82, 32, 3) * 255).astype(np.uint8)).resize((S, 8)).resize((S, S)), np.float32) / 255
    base = shade_mult(base, 0.85 + streak * 0.2)
    return base


def tex_concrete():
    n = fbm(90, 4)
    base = lerp((128, 128, 124), (168, 166, 160), n)
    base = shade_mult(base, 0.88 + rng.random((S, S)).astype(np.float32) * 0.16)
    cr = fbm(91, 5, 4)
    crack = np.clip(1 - np.abs(cr - 0.5) * 70, 0, 1) * 0.14
    base = shade_mult(base, 1 - crack)
    return base


def tex_asphalt():
    base = lerp((50, 50, 52), (78, 78, 80), fbm(100, 8))
    g = rng.random((S, S)).astype(np.float32)
    base = shade_mult(base, 0.75 + g * 0.5)
    return base


def tex_bark():
    n = np.asarray(Image.fromarray((fbm(110, 16, 5) * 255).astype(np.uint8)).resize((S, S // 6), Image.BICUBIC).resize((S, S), Image.BICUBIC), np.float32) / 255
    base = lerp((60, 44, 32), (112, 88, 64), n)
    f = np.abs(np.sin(np.arange(S)[None, :] / S * math.pi * 14 + fbm(111, 4) * 6))
    base = shade_mult(base, 0.55 + f * 0.5)
    base = shade_mult(base, 0.85 + fbm(112, 32, 3) * 0.25)
    return base


def tex_pine():
    base = lerp((22, 38, 22), (40, 62, 34), fbm(120, 6))
    img = to_img(base)
    cols = [(30, 52, 28), (44, 70, 36), (56, 82, 42), (20, 34, 20), (64, 88, 50)]
    a = strokes(img, 16000, (6, 14), (1, 2), cols, angle_spread=math.pi * 2, seed=121)
    a = shade_mult(a, 0.7 + fbm(122, 8, 4) * 0.45)
    return a


def tex_leaves():
    base = lerp((26, 40, 20), (44, 62, 30), fbm(130, 6))
    img = to_img(base)
    cols = [(52, 80, 34), (70, 98, 42), (88, 112, 50), (44, 66, 30), (104, 118, 58)]
    a = blobs(img, 2600, (4, 10), cols, seed=131, shade=True)
    a = shade_mult(a, 0.75 + fbm(132, 6, 4) * 0.4)
    return a


def tex_fabric():
    x = np.arange(S, dtype=np.float32)
    wv = (np.sin(x[None, :] * 1.6) * np.sin(x[:, None] * 1.6)) * 0.5 + 0.5
    base = np.full((S, S), 205, np.float32) * (0.9 + wv * 0.1) * (0.9 + fbm(140, 8, 4) * 0.15)
    return np.repeat(base[..., None], 3, axis=2)


def tex_plain():
    base = np.full((S, S), 226, np.float32) * (0.95 + fbm(150, 6, 4) * 0.08)
    return np.repeat(base[..., None], 3, axis=2)


LAYERS = [tex_grass, tex_dirt, tex_rock, tex_sand, tex_plaster, tex_brick, tex_roof, tex_wood,
          tex_metal, tex_concrete, tex_asphalt, tex_bark, tex_pine, tex_leaves, tex_fabric, tex_plain]


def build_atlas():
    atlas = Image.new("RGB", (S * 4, S * 4))
    for i, fn in enumerate(LAYERS):
        arr = fn()
        im = to_img(arr)
        atlas.paste(im, ((i % 4) * S, (i // 4) * S))
        print("textura", i, fn.__name__)
    path = os.path.join(ROOT, "textures", "atlas.png")
    atlas.save(path, optimize=True)
    print("ok", path)


# ---------------------------------------------------------------- sons

RATE = 22050


def env_exp(n, decay, attack=0.002):
    t = np.arange(n) / RATE
    e = np.exp(-t * decay)
    a = int(attack * RATE)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def lowpass(x, cutoff):
    a = math.exp(-2 * math.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def wn(n, seed):
    return np.random.default_rng(seed).uniform(-1, 1, n)


def secs(s):
    return int(s * RATE)


def save(name, x, gain=0.9):
    x = np.asarray(x, np.float64)
    m = np.max(np.abs(x)) + 1e-9
    x = x / m * gain
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(ROOT, "sounds", name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def gunshot(dur, crack, body_lp, body_decay, thump_f, thump_decay, tail, seed, suppressed=False):
    n = secs(dur)
    t = np.arange(n) / RATE
    x = np.zeros(n)
    c = wn(n, seed) * env_exp(n, 900) * crack
    if suppressed:
        c *= 0.15
    x += highpass(c, 1500)
    body = lowpass(wn(n, seed + 1), body_lp) * env_exp(n, body_decay, 0.001) * 2.5
    x += body
    x += np.sin(2 * math.pi * thump_f * t * (1 - t * 0.6)) * env_exp(n, thump_decay) * 0.9
    x += lowpass(wn(n, seed + 2), 900) * env_exp(n, 7) * tail
    if suppressed:
        x = lowpass(x, 2500) * 0.7
    return x


def footstep(seed, hard):
    n = secs(0.16)
    x = np.zeros(n)
    r = np.random.default_rng(seed)
    if hard:
        x += highpass(wn(n, seed), 800) * env_exp(n, 160) * 0.6
        t = np.arange(n) / RATE
        x += np.sin(2 * math.pi * r.uniform(100, 140) * t) * env_exp(n, 60) * 0.8
        x = lowpass(x, 4000)
    else:
        # vários estalinhos de grama/terra
        for k in range(5):
            o = int(r.uniform(0, 0.05) * RATE)
            m = secs(0.05)
            b = bandpass(wn(m, seed + k), 700, 5000) * env_exp(m, 90) * r.uniform(0.4, 1)
            x[o:o + m] += b[:n - o]
        x += lowpass(wn(n, seed + 9), 300) * env_exp(n, 40) * 0.8
    return x


def build_sounds():
    save("shot_pistol", gunshot(0.35, 1.0, 3500, 30, 120, 25, 0.25, 1))
    save("shot_deagle", gunshot(0.5, 1.2, 2500, 18, 80, 18, 0.45, 2))
    save("shot_smg", gunshot(0.25, 0.8, 3800, 38, 140, 35, 0.18, 3))
    save("shot_rifle", gunshot(0.45, 1.1, 3000, 24, 90, 22, 0.4, 4))
    save("shot_ak", gunshot(0.5, 1.2, 2400, 20, 75, 18, 0.5, 5))
    save("shot_shotgun", gunshot(0.7, 1.3, 1800, 12, 55, 12, 0.7, 6))
    save("shot_sniper", gunshot(0.9, 1.5, 2000, 10, 50, 9, 0.9, 7))
    save("shot_silenced", gunshot(0.25, 0.5, 2000, 45, 160, 40, 0.1, 8, True), 0.6)
    for i in range(3):
        save("step_grass%d" % i, footstep(20 + i, False), 0.7)
        save("step_hard%d" % i, footstep(30 + i, True), 0.7)
    n = secs(0.25)
    save("jump", bandpass(wn(n, 40), 300, 2500) * env_exp(n, 25, 0.03), 0.5)
    save("land", footstep(42, False) * 1.4 + np.pad(footstep(43, True), (0, 0)) * 0.5, 0.8)
    # pular janela: pano + mão batendo no peitoril + pé no chão
    n = secs(0.55)
    v = bandpass(wn(n, 50), 400, 3000) * env_exp(n, 9, 0.05) * 0.5
    hit = np.zeros(n)
    hs = footstep(51, True)
    hit[:len(hs)] += hs
    o = secs(0.35)
    hs2 = footstep(52, False)
    hit[o:o + len(hs2)] += hs2[:n - o]
    save("vault", v + hit, 0.8)
    # trocar arma: dois cliques metálicos
    n = secs(0.3)
    x = np.zeros(n)
    for k, o in enumerate((0.0, 0.12)):
        m = secs(0.05)
        c = bandpass(wn(m, 60 + k), 2000, 8000) * env_exp(m, 120)
        i0 = secs(o)
        x[i0:i0 + m] += c
    x += bandpass(wn(n, 62), 200, 1500) * env_exp(n, 20) * 0.3
    save("switch", x, 0.6)
    # recarga: carregador saindo e entrando
    n = secs(0.25)
    save("reload_out", bandpass(wn(n, 70), 1500, 6000) * env_exp(n, 40) + bandpass(wn(n, 71), 150, 900) * env_exp(n, 25) * 0.5, 0.6)
    n = secs(0.3)
    x = bandpass(wn(n, 72), 1200, 7000) * env_exp(n, 60)
    x[secs(0.08):] += (bandpass(wn(n - secs(0.08), 73), 2500, 9000) * env_exp(n - secs(0.08), 90)) * 1.2
    save("reload_in", x, 0.7)
    n = secs(0.35)
    x = bandpass(wn(n, 74), 1800, 7000) * env_exp(n, 50)
    x[secs(0.15):] += bandpass(wn(n - secs(0.15), 75), 1800, 7000) * env_exp(n - secs(0.15), 50)
    save("bolt", x, 0.6)
    n = secs(0.3)
    save("pickup", bandpass(wn(n, 80), 500, 4000) * env_exp(n, 14, 0.02), 0.5)
    n = secs(0.4)
    t = np.arange(n) / RATE
    save("equip", bandpass(wn(n, 81), 800, 5000) * env_exp(n, 15, 0.02) + np.sin(2 * math.pi * 900 * t) * env_exp(n, 30) * 0.3, 0.5)
    # curativo: rasgando fita
    n = secs(0.8)
    tear = bandpass(wn(n, 90), 1500, 7000) * (0.5 + 0.5 * np.abs(np.sin(np.arange(n) / RATE * 70))) * env_exp(n, 3, 0.05)
    save("heal", tear, 0.5)
    n = secs(0.6)
    t = np.arange(n) / RATE
    save("heal_done", (np.sin(2 * math.pi * 660 * t) * env_exp(n, 8) + np.sin(2 * math.pi * 990 * t) * env_exp(n, 10) * 0.6) * np.minimum(1, t / 0.01), 0.35)
    n = secs(0.06)
    t = np.arange(n) / RATE
    save("hit", np.sin(2 * math.pi * 1900 * t) * env_exp(n, 60) + highpass(wn(n, 100), 3000) * env_exp(n, 200) * 0.3, 0.45)
    n = secs(0.25)
    t = np.arange(n) / RATE
    save("headshot", np.sin(2 * math.pi * 2600 * t) * env_exp(n, 16) + np.sin(2 * math.pi * 3900 * t) * env_exp(n, 22) * 0.5, 0.45)
    n = secs(0.5)
    t = np.arange(n) / RATE
    k = np.sin(2 * math.pi * (500 + 300 * t) * t) * env_exp(n, 7) + np.sin(2 * math.pi * 1000 * t) * env_exp(n, 12) * 0.4
    save("kill", k, 0.5)
    n = secs(0.25)
    save("punch_swing", bandpass(wn(n, 110), 300, 2000) * np.sin(np.linspace(0, math.pi, n)) ** 2, 0.4)
    n = secs(0.2)
    t = np.arange(n) / RATE
    save("punch_hit", lowpass(wn(n, 111), 1200) * env_exp(n, 30) + np.sin(2 * math.pi * 90 * t) * env_exp(n, 30), 0.8)
    n = secs(0.9)
    flap = bandpass(wn(n, 120), 150, 1500) * env_exp(n, 4, 0.08) * (0.6 + 0.4 * np.sin(np.arange(n) / RATE * 50))
    save("chute", flap, 0.7)
    n = secs(0.35)
    t = np.arange(n) / RATE
    save("zone", np.sign(np.sin(2 * math.pi * 520 * t)) * 0.3 * env_exp(n, 6) * (t < 0.3), 0.35)
    n = secs(0.05)
    save("click", bandpass(wn(n, 130), 2000, 8000) * env_exp(n, 150), 0.4)
    n = secs(0.08)
    save("empty", bandpass(wn(n, 131), 2500, 9000) * env_exp(n, 120), 0.4)
    n = secs(0.2)
    save("impact", bandpass(wn(n, 140), 400, 4000) * env_exp(n, 50), 0.4)
    n = secs(0.25)
    save("ricochet", bandpass(wn(n, 141), 2000, 8000) * env_exp(n, 30) + np.sin(2 * math.pi * (3000 - 4000 * np.arange(n) / RATE) * np.arange(n) / RATE) * env_exp(n, 15) * 0.3, 0.35)
    n = secs(0.3)
    save("hurt", lowpass(wn(n, 150), 700) * env_exp(n, 18, 0.01), 0.6)
    print("sons ok")


if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "textures"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "sounds"), exist_ok=True)
    build_sounds()
    build_atlas()
