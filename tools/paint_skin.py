#!/usr/bin/env python3
"""Textura do personagem (camisa, bermuda, tênis, pele e cabelo) pintada por regiões 3D.

Entrada: dump.npz do Blender (posição/normal de repouso por vértice, triângulos com o UV novo).
Cada texel acha o ponto 3D dele no boneco (pose T, metros, frente = -Y) e a região sai de cortes
no espaço 3D (barra da camisa, manga, bainha da bermuda, cano do tênis), então as bordas são
retas e as costuras do UV não aparecem (o padrão do tecido também é 3D).
Uso: python3 tools/paint_skin.py dump.npz saida.png [skin]
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

S = 1024
SS = 2          # pinta em 2048 e reduz (bordas lisas, sem serrilhado)
SKINS = {
    # camisa, bermuda, tênis (cabedal), sola/detalhe, pele, cabelo
    "padrao": {"shirt": (0.27, 0.36, 0.44), "shorts": (0.60, 0.54, 0.42), "shoe": (0.90, 0.90, 0.88),
               "shoe2": (0.22, 0.23, 0.25), "skin": (0.80, 0.60, 0.47), "hair": (0.16, 0.11, 0.08)},
}


def hash3(p):
    p = np.floor(p).astype(np.int64)
    h = (p[..., 0] * 73856093) ^ (p[..., 1] * 19349663) ^ (p[..., 2] * 83492791)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(p):
    i = np.floor(p)
    f = p - i
    f = f * f * (3 - 2 * f)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[..., 0] if dx else 1 - f[..., 0]) * (f[..., 1] if dy else 1 - f[..., 1]) * (f[..., 2] if dz else 1 - f[..., 2])
                out = out + w * hash3(i + np.array([dx, dy, dz]))
    return out


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def rasterize(d, S):
    pos, nrm, tris, tuv = d["pos"], d["nrm"], d["tris"], d["tuv"]
    gn = list(d["gn"])
    hw_v = sum(d["W"][:, gn.index(k)] for k in ("head", "neck_01", "head_leaf") if k in gn)
    P = np.zeros((S, S, 3), np.float32)
    N = np.zeros((S, S, 3), np.float32)
    H = np.zeros((S, S), np.float32)
    M = np.zeros((S, S), bool)
    for t, uv in zip(tris, tuv):
        q = np.array(uv) * S
        q[:, 1] = S - q[:, 1]
        x0, y0 = np.floor(q.min(0)).astype(int) - 4
        x1, y1 = np.ceil(q.max(0)).astype(int) + 4
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, S - 1), min(y1, S - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        a, b, c = q
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        l0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        l1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        l2 = 1 - l0 - l1
        # cada ilha pinta 3 px (de 2048) além da borda dela: a emenda e o mipmap nunca puxam cor da ilha vizinha
        area2 = abs(den)
        hgt = [area2 / max(np.linalg.norm(q[(i + 1) % 3] - q[(i + 2) % 3]), 1e-6) for i in range(3)]
        ins = (l0 >= -3.0 / hgt[0]) & (l1 >= -3.0 / hgt[1]) & (l2 >= -3.0 / hgt[2])
        if not ins.any():
            continue
        L = np.clip(np.stack([l0, l1, l2], -1)[ins], 0, None)
        L /= L.sum(-1, keepdims=True)
        inner = (np.stack([l0, l1, l2], -1)[ins] >= 0).all(-1)
        yy = (ys[ins] - 0.5).astype(int)
        xx = (xs[ins] - 0.5).astype(int)
        # pixel de dentro do triângulo ganha de pixel de borda esticada
        keep = inner | ~M[yy, xx]
        yy, xx, L = yy[keep], xx[keep], L[keep]
        P[yy, xx] = L @ pos[t]
        nn = L @ nrm[t]
        N[yy, xx] = nn / np.maximum(np.linalg.norm(nn, axis=-1, keepdims=True), 1e-6)
        H[yy, xx] = L @ hw_v[t]
        M[yy, xx] = True
    return P, N, M, H


def paint(P, N, M, H, sk):
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    ax = np.abs(x)
    col = np.zeros(P.shape, np.float32)
    C = {k: np.array(v, np.float32) for k, v in sk.items()}
    fine = vnoise(P * 900.0)                      # trama do tecido
    mid = vnoise(P * 60.0)                        # manchas grandes (desbotado)
    # ---- regiões ----
    arm = (ax > 0.2) & (z > 1.3)
    head = (z > 1.47) & ~arm
    # gola careca: mais baixa na frente
    # gola careca: curva que sobe do peito pro ombro (mais alta atrás, um pouco funda na frente)
    front = np.clip(-(y - 0.02) / 0.08, 0, 1)
    back = np.clip((y - 0.02) / 0.06, 0, 1)
    collar_z = 1.494 + 2.4 * ax * ax + 0.018 * back - 0.008 * front * np.exp(-(ax / 0.05) ** 2)
    hem_z = 0.965 + 0.012 * np.cos(x * 9.0)
    sleeve_x = 0.37 - 0.02 * np.clip(-y / 0.06, -1, 1)
    shirt = (z > hem_z) & (z < np.minimum(collar_z, 1.56)) & ~(arm & (ax > sleeve_x))
    shirt |= arm & (ax <= sleeve_x) & (z < 1.58)
    head = head & ~shirt
    shorts_hem = 0.60 + 0.012 * np.clip(y / 0.06, -1, 1)
    shorts = (z <= hem_z) & (z > shorts_hem) & ~arm
    shoe_top = 0.125 + 0.03 * np.clip((y - 0.0) / 0.06, 0, 1)
    shoe = (z < shoe_top) & (ax < 0.3)
    sock = (z >= shoe_top) & (z < shoe_top + 0.045) & (ax < 0.3)
    # cabelo: topo e nuca, linha da testa mais alta
    # cabelo curto: testa com entradas, lateral mais baixa (costeleta) e nuca; borda irregular
    hy = (y - (-0.012)) / 0.11
    ang = np.arctan2(x, -(y + 0.012))
    temple = np.exp(-((np.abs(ang) - 0.55) / 0.22) ** 2)
    hairline = 1.688 + 0.035 * np.clip(-hy, 0, 1) - 0.075 * np.clip(hy, 0, 1) + 0.018 * temple
    hairline -= 0.03 * np.exp(-((np.abs(ang) - 1.45) / 0.25) ** 2)
    hairline += 0.004 * (vnoise(P * 400.0) - 0.5)
    hair = head & (z > hairline)
    skin = M & ~(shirt | shorts | shoe | sock | hair)
    # ---- pele ----
    col[skin] = C["skin"] * (0.96 + 0.06 * mid[skin])[:, None]
    # ---- camisa ----
    sc = C["shirt"][None] * (0.93 + 0.05 * fine[shirt] + 0.06 * mid[shirt])[:, None]
    col[shirt] = sc
    # gola canelada (faixa de 1,6 cm) e barras com costura dupla
    rib = shirt & (z > collar_z - 0.016)
    col[rib] *= (0.82 + 0.08 * (np.sin(np.arctan2(y[rib], x[rib]) * 90) > 0))[:, None]
    sl = shirt & arm & (ax > sleeve_x - 0.022)
    col[sl] *= 0.86
    hm = shirt & ~arm & (z < hem_z + 0.022)
    col[hm] *= 0.86
    for band, dist in ((sl, sleeve_x - 0.016 - ax), (hm, z - hem_z - 0.016)):
        st = band & (np.abs(dist) < 0.0012) & (np.sin((x + y + z) * 1400) > -0.2)
        col[st] *= 0.72
    # ---- bermuda ----
    bc = C["shorts"][None] * (0.92 + 0.07 * fine[shorts] + 0.06 * mid[shorts])[:, None]
    col[shorts] = bc
    cuff = shorts & (z < shorts_hem + 0.03)
    col[cuff] *= 0.88
    st = shorts & (np.abs(z - (shorts_hem + 0.024)) < 0.0013) & (np.sin((x + y) * 1400) > -0.2)
    col[st] *= 0.72
    # bolso na lateral e costura da frente
    pocket = shorts & (np.abs(ax - (0.089 + 0.085)) < 0.0018) & (z > 0.80) & (z < 0.93)
    col[pocket] *= 0.75
    fly = shorts & (y < -0.05) & (np.abs(x) < 0.0016) & (z > 0.82)
    col[fly] *= 0.78
    # sombra embaixo da barra da camisa e entre as pernas
    ao = 1 - 0.28 * (1 - sstep(0.0, 0.03, hem_z - z)) * shorts
    col *= ao[..., None]
    inner = shorts & (ax < 0.05) & (z < 0.88)
    col[inner] *= (0.92 + 0.08 * sstep(0.0, 0.05, ax[inner]))[:, None]
    # ---- meia ----
    col[sock] = np.array([0.92, 0.92, 0.9]) * (0.95 + 0.05 * fine[sock])[:, None]
    stripe = sock & (np.abs(z - (shoe_top + 0.03)) < 0.004)
    col[stripe] = C["shoe2"] * 1.2
    # ---- tênis ----
    sole = shoe & (z < 0.028)
    mids = shoe & (z >= 0.028) & (z < 0.04)
    upper = shoe & (z >= 0.04)
    col[upper] = C["shoe"] * (0.95 + 0.05 * fine[upper])[:, None]
    col[mids] = np.array([0.97, 0.97, 0.96])
    col[sole] = C["shoe2"]
    # bico reforçado, calcanhar e faixa lateral
    fx = x - np.sign(x) * 0.089
    toe = upper & (y < -0.19) & (z < 0.07)
    col[toe] = C["shoe"] * 0.86
    heel = upper & (y > 0.03) & (z < 0.11)
    col[heel] = C["shoe2"] * 1.15
    side = upper & (np.abs(fx) > 0.03) & (np.abs(z - (0.065 + (y + 0.05) * 0.25)) < 0.008) & (y > -0.17) & (y < 0.03)
    col[side] = C["shoe2"] * 1.1
    # cadarço em X em cima do peito do pé
    lace_zone = upper & (np.abs(fx) < 0.022) & (y < -0.04) & (y > -0.16) & (N[..., 2] > 0.25)
    lz = (y + 0.04) / 0.024
    lace = lace_zone & ((np.abs(np.abs(fx) - np.abs(((lz % 1.0) - 0.5) * 0.04)) < 0.0035))
    col[lace_zone] *= 0.9
    col[lace] = np.array([0.98, 0.98, 0.98])
    # ---- cabelo ----
    hn = vnoise(P * np.array([500.0, 500.0, 90.0])) * 0.6 + vnoise(P * 1500.0) * 0.4
    col[hair] = C["hair"] * (0.85 + 0.3 * hn[hair])[:, None]
    # transição suave na borda (fios ralos), sem linha dura
    edge = head & (z > hairline - 0.008) & (z <= hairline + 0.01)
    t = sstep(-0.008, 0.01, z - hairline)[edge][:, None]
    col[edge] = (C["skin"] * 0.9) * (1 - t) + C["hair"] * (0.85 + 0.3 * hn[edge])[:, None] * t
    # sobrancelhas e olhos bem simples (o rosto não fica liso de manequim)
    face = head & ~hair & (y < -0.06)
    for sx in (-1, 1):
        ex = sx * 0.032
        brow = face & (np.abs(x - ex) < 0.017) & (np.abs(z - 1.668 + 0.004 * np.abs(x - ex) / 0.017) < 0.0035)
        col[brow] = C["hair"] * 1.1
        eye = face & (((x - ex) / 0.011) ** 2 + ((z - 1.648) / 0.0055) ** 2 < 1)
        col[eye] = np.array([0.96, 0.95, 0.92])
        iris = face & (((x - ex) / 0.0052) ** 2 + ((z - 1.648) / 0.0052) ** 2 < 1)
        col[iris] = np.array([0.18, 0.12, 0.08])
    mouth = face & (np.abs(x) < 0.018) & (np.abs(z - 1.598) < 0.0022)
    col[mouth] = C["skin"] * 0.62
    return np.clip(col, 0, 1), {"shirt": shirt, "shorts": shorts, "shoe": shoe, "hair": hair, "skin": skin}


def main():
    d = np.load(sys.argv[1])
    sk = SKINS[sys.argv[3] if len(sys.argv) > 3 else "padrao"]
    P, N, M, H = rasterize(d, S * SS)
    col, _ = paint(P, N, M, H, sk)
    # sangra a cor pra fora das ilhas do UV (sem linha preta na emenda nem no mipmap)
    idx = ndimage.distance_transform_edt(~M, return_distances=False, return_indices=True)
    col = col[idx[0], idx[1]]
    col = col.reshape(S, SS, S, SS, 3).mean((1, 3))
    Image.fromarray((col * 255 + 0.5).astype(np.uint8)).save(sys.argv[2])
    print("salvo", sys.argv[2], "cobertura %.1f%%" % (M.mean() * 100))


if __name__ == "__main__":
    main()
