#!/usr/bin/env python3
"""Árvore do Tripo: junta as 18 texturas num atlas e reduz a malha pra celular.

Uso: python3 tools/tripo_tree.py <pasta_tmp> <pasta_fbm>
  - lê <pasta_tmp>/parts.txt e <parte>.obj (do tools/prepare_tripo_tree.gd, TREE_STAGE=dump)
  - lê <pasta_fbm>/tree_3d_model_tripo_part_N_basecolor.PNG
  - salva models/trees/tripo_atlas.png e <pasta_tmp>/tree_lod0.obj (perto) e tree_lod1.obj (longe)
Precisa de numpy, scipy, pillow e pymeshlab.
"""
import os
import sys

import numpy as np
import pymeshlab
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TMP, FBM = sys.argv[1], sys.argv[2]
TILE = 256
COLS, ROWS = 5, 4
PAD = 6

parts = [p for p in open(os.path.join(TMP, "parts.txt")).read().split("\n") if p]
atlas = Image.new("RGB", (COLS * TILE, ROWS * TILE), (60, 70, 50))
V, T, F = [], [], []
PARTS = []
for k, name in enumerate(parts):
    n = name.split("_")[-1]
    img = Image.open(os.path.join(FBM, "tree_3d_model_tripo_part_%s_basecolor.PNG" % n)).convert("RGB")
    cx, cy = k % COLS, k // COLS
    inner = TILE - PAD * 2
    tile = img.resize((inner, inner), Image.LANCZOS)
    # borda repetida (não vaza cor de outra parte nos mipmaps)
    big = Image.new("RGB", (TILE, TILE))
    big.paste(tile.resize((TILE, TILE), Image.LANCZOS), (0, 0))
    big.paste(tile, (PAD, PAD))
    atlas.paste(big, (cx * TILE, cy * TILE))
    vs, ts, fs = [], [], []
    for line in open(os.path.join(TMP, name + ".obj")):
        p = line.split()
        if not p:
            continue
        if p[0] == "v":
            vs.append([float(x) for x in p[1:4]])
        elif p[0] == "vt":
            u, v = float(p[1]), float(p[2])
            u = min(max(u, 0.0), 1.0)
            v = min(max(v, 0.0), 1.0)
            # vt do OBJ: v cresce pra cima; no atlas a linha 0 fica em cima
            uu = (cx * TILE + PAD + u * inner) / atlas.width
            vv = 1.0 - (cy * TILE + PAD + (1.0 - v) * inner) / atlas.height
            ts.append([uu, vv])
        elif p[0] == "f":
            fs.append([int(q.split("/")[0]) - 1 for q in p[1:4]])
    PARTS.append((vs, ts, fs))
    base = len(V)
    V += vs
    T += ts
    F += [[a + base, b + base, c + base] for a, b, c in fs]
atlas.save(os.path.join(ROOT, "models", "trees", "tripo_atlas.png"))
print("atlas", atlas.size, "partes", len(parts), "tris", len(F))

# redução parte por parte (cada parte usa um pedaço só do atlas): reduz só a forma (rápido) e cada
# ponto novo pega a textura do ponto original mais perto da mesma parte
from scipy.spatial import cKDTree

TARGET = (1800, 320)   # triângulos perto / longe (no total)
total = len(F)
outs = [([], [], []) for _ in TARGET]
TRUNK = 1.5   # tronco mais grosso (igual às árvores antigas: dá pra se proteger atrás)
for (vs, ts, fs) in PARTS:
    vs = np.array(vs, dtype=np.float64)
    if vs[:, 1].min() < 0.3:
        # é o tronco (única parte que encosta no chão): engrossa em volta do eixo, sem mexer na altura
        base = vs[vs[:, 1] < 1.0]
        cx, cz = base[:, 0].mean(), base[:, 2].mean()
        vs[:, 0] = cx + (vs[:, 0] - cx) * TRUNK
        vs[:, 2] = cz + (vs[:, 2] - cz) * TRUNK
    ts = np.array(ts, dtype=np.float64)
    fs = np.array(fs, dtype=np.int32)
    tree = cKDTree(vs)
    for lod, tgt in enumerate(TARGET):
        n = max(16, int(len(fs) * tgt / total))
        ms = pymeshlab.MeshSet()
        ms.add_mesh(pymeshlab.Mesh(vertex_matrix=vs, face_matrix=fs))
        ms.meshing_remove_duplicate_vertices()
        if ms.current_mesh().face_number() > n:
            ms.meshing_decimation_quadric_edge_collapse(targetfacenum=n, qualitythr=0.3, preserveboundary=False,
                                                        optimalplacement=False, preservenormal=True, planarquadric=True)
        cm = ms.current_mesh()
        if os.environ.get("DBG"):
            print("  parte", len(fs), "->", cm.face_number(), "lod", lod, "miny %.2f -> %.2f" % (vs[:, 1].min(), cm.vertex_matrix()[:, 1].min() if cm.vertex_number() else -1), "nv", cm.vertex_number())
        nv = cm.vertex_matrix()
        nf = cm.face_matrix()
        _, near = tree.query(nv)
        ov, ot, of = outs[lod]
        base = len(ov)
        ov += nv.tolist()
        ot += ts[near].tolist()
        of += (nf + base).tolist()
for lod in range(len(TARGET)):
    ov, ot, of = outs[lod]
    with open(os.path.join(TMP, "tree_lod%d.obj" % lod), "w") as f:
        for p in ov:
            f.write("v %f %f %f\n" % tuple(p))
        for t in ot:
            f.write("vt %f %f\n" % tuple(t))
        for a, b, c in of:
            f.write("f %d/%d %d/%d %d/%d\n" % (a + 1, a + 1, b + 1, b + 1, c + 1, c + 1))
    print("lod", lod, len(of), "triângulos")
