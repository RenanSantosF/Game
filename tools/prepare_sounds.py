#!/usr/bin/env python3
"""Recorta e normaliza os sons gravados (CC0) usados no jogo.

Fontes (todas CC0, opengameart.org):
  - "The Free Firearm Sound Library"            -> tiros
  - "Fantozzi's Footsteps (Grass/Sand & Stone)" -> passos
  - "42 Snow and Gravel Footsteps" (Corsica_S)  -> passos no cascalho
Uso: python3 tools/prepare_sounds.py <pasta_com_os_pacotes_extraidos>
Precisa de ffmpeg e numpy. Saída em sounds/.
"""
import os
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 44100

GUNS = {  # som -> (pasta da biblioteca, duração do recorte, eco, grave)
    "shot_pistol": ("Walther PPQ", 0.5, 0.5, 0.15),
    "shot_deagle": ("1911", 0.6, 0.7, 0.35),
    "shot_smg": ("Carl Gustav M45", 0.35, 0.4, 0.1),
    "shot_ump": ("PPSh", 0.35, 0.45, 0.15),
    "shot_rifle": ("AR-15", 0.6, 0.8, 0.3),
    "shot_scar": ("SKS", 0.6, 0.85, 0.35),
    "shot_ak": ("AK-47", 0.6, 0.9, 0.45),
    "shot_shotgun": ("Mossberg", 0.8, 1.0, 0.6),
    "shot_m1014": ("Nova", 0.8, 0.9, 0.55),
    "shot_bolt": ("Mosin Nagant", 0.9, 1.3, 0.6),
    "shot_sniper": ("Tikka", 1.0, 1.5, 0.7),
}


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def save(name, x, gain=0.95):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(ROOT, "sounds", name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def isolated_hit(x, want):
    """Escolhe o tiro mais isolado da gravação (o que tem mais silêncio depois)."""
    env = np.abs(x)
    w = int(0.03 * RATE)
    thr = 0.35 * env.max()
    peaks = []
    i = 0
    while i < len(env):
        if env[i] > thr:
            j = i + int(np.argmax(env[i:i + w]))
            peaks.append(j)
            i = j + w
        else:
            i += 1
    best = peaks[0]
    best_gap = 0
    for k, pk in enumerate(peaks):
        gap = (peaks[k + 1] if k + 1 < len(peaks) else len(x)) - pk
        if gap > best_gap:
            best_gap = gap
            best = pk
        if gap >= want * RATE:
            best = pk
            best_gap = gap
            break
    start = max(0, best - int(0.004 * RATE))
    return start, min(want, (best_gap - int(0.006 * RATE)) / RATE)


def punch(x, tail, boom):
    """Deixa o tiro mais forte: um pouco de saturação, grave e eco de ambiente aberto."""
    n = len(x)
    rng = np.random.default_rng(7)
    ir_len = int(tail * RATE)
    t = np.arange(ir_len) / RATE
    ir = rng.standard_normal(ir_len) * np.exp(-t * (6.0 / tail))
    # eco mais escuro (passa-baixa simples)
    k = 12
    ir = np.convolve(ir, np.ones(k) / k, mode="same")
    ir[:int(0.012 * RATE)] = 0.0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    y = np.concatenate([x, np.zeros(ir_len)])
    rev = np.convolve(y, ir)[:len(y)]
    rev /= np.max(np.abs(rev)) + 1e-9
    y = y / (np.max(np.abs(y)) + 1e-9) + rev * 0.28
    tt = np.arange(len(y)) / RATE
    y += np.sin(2 * np.pi * 55 * tt) * np.exp(-tt * 14) * boom
    y = np.tanh(y * 1.8)
    m = len(y)
    f = int(m * 0.35)
    y[m - f:] *= np.linspace(1, 0, f) ** 2
    return y


def first_hit(x, thr=0.5):
    env = np.abs(x)
    i = int(np.argmax(env > thr * env.max()))
    return max(0, i - int(0.004 * RATE))


def cut(x, start, dur, fade=0.4):
    seg = x[start:start + int(dur * RATE)].copy()
    n = len(seg)
    f = int(n * fade)
    seg[n - f:] *= np.linspace(1, 0, f) ** 2
    seg[:int(0.002 * RATE)] *= np.linspace(0, 1, int(0.002 * RATE))
    return seg


def main(src):
    lib = os.path.join(src, "fire", "Prepared SFX Library")
    for name, (folder, dur, tail, boom) in GUNS.items():
        d = os.path.join(lib, folder)
        f = sorted(x for x in os.listdir(d) if x.lower().endswith(".wav"))[0]
        x = load(os.path.join(d, f))
        st, dd = isolated_hit(x, dur)
        save(name, punch(cut(x, st, dd), tail, boom), 0.97)
        print("tiro", name, folder, f)
    fz = os.path.join(src, "fant", "Fantozzi-footsteps", "ogg")
    for i, f in enumerate(["Fantozzi-SandL1", "Fantozzi-SandR1", "Fantozzi-SandL2", "Fantozzi-SandR2", "Fantozzi-SandL3", "Fantozzi-SandR3"]):
        x = load(os.path.join(fz, f + ".ogg"))
        save("step_grass%d" % i, cut(x, first_hit(x, 0.2), 0.35, 0.5), 0.8)
    for i, f in enumerate(["Fantozzi-StoneL1", "Fantozzi-StoneR1", "Fantozzi-StoneL2", "Fantozzi-StoneR2", "Fantozzi-StoneL3", "Fantozzi-StoneR3"]):
        x = load(os.path.join(fz, f + ".ogg"))
        save("step_hard%d" % i, cut(x, first_hit(x, 0.2), 0.3, 0.5), 0.8)
    cs = os.path.join(src, "snow", "Corsica_S-Walking_in_Snow")
    for i in range(6):
        x = load(os.path.join(cs, "Corsica_S-Walking_on_snow_covered_gravel_%02d.flac" % (i + 1)))
        save("step_gravel%d" % i, cut(x, first_hit(x, 0.25), 0.4, 0.5), 0.8)
    # queda no chão: passo de pedra mais grave e forte
    x = load(os.path.join(fz, "Fantozzi-StoneL1.ogg"))
    s = cut(x, first_hit(x, 0.2), 0.4, 0.5)
    idx = np.arange(0, len(s), 0.7)
    land = np.interp(idx, np.arange(len(s)), s)
    t = np.arange(len(land)) / RATE
    land = land + np.sin(2 * np.pi * 70 * t) * np.exp(-t * 18) * 0.6
    save("land", land, 0.9)


if __name__ == "__main__":
    main(sys.argv[1])
