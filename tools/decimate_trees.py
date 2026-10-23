# Reduz troncos e galhos das árvores (OBJs exportados pelo tools/prepare_trees.gd).
# A casca usa projeção triplanar no jogo, então não precisa manter as UVs (bem mais rápido).
# Gera <nome>_lod0.obj (perto) e <nome>_lod1.obj (longe).
# Uso: python3 tools/decimate_trees.py <pasta>   (precisa do pymeshlab)
import glob
import os
import sys

import pymeshlab

TARGET = {"trunk": (700, 220), "branches": (1100, 260), "": (700, 220)}

d = sys.argv[1]
for path in sorted(glob.glob(os.path.join(d, "*__*.obj"))):
    if "_lod" in path:
        continue
    name = os.path.basename(path)[:-4]
    part = "branches" if "branch" in name else ("trunk" if "trunk" in name else "")
    for i, n in enumerate(TARGET[part]):
        ms = pymeshlab.MeshSet()
        ms.load_new_mesh(path)
        ms.meshing_remove_duplicate_vertices()
        while ms.current_mesh().face_number() > n:
            alvo = max(n, ms.current_mesh().face_number() // 2)
            ms.meshing_decimation_quadric_edge_collapse(
                targetfacenum=alvo, qualitythr=0.3, preserveboundary=False, preservetopology=False,
                optimalplacement=True, preservenormal=True, planarquadric=True)
        print(name, "lod", i, ms.current_mesh().face_number(), "faces", flush=True)
        ms.save_current_mesh(os.path.join(d, name + "_lod%d.obj" % i), save_vertex_normal=False, save_wedge_texcoord=False,
                             save_vertex_color=False, save_textures=False)
