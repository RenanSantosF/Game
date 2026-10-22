# Reduz a malha do personagem (hi.obj exportado pelo tools/prepare_man.gd) mantendo as costuras
# da textura no lugar. Gera lod0.obj (perto) e lod1.obj (longe) na mesma pasta.
# Uso: python3 tools/decimate_man.py <pasta>   (precisa do pymeshlab: pip install pymeshlab)
import sys
import pymeshlab

LODS = [9000, 2200]

d = sys.argv[1]
for i, n in enumerate(LODS):
    ms = pymeshlab.MeshSet()
    ms.load_new_mesh(d + "/hi.obj")
    m = ms.current_mesh()
    print("origem", m.vertex_number(), "vértices", m.face_number(), "faces")
    # em etapas: cada passada corta pela metade, que dá resultado melhor que um corte só
    while ms.current_mesh().face_number() > n:
        alvo = max(n, ms.current_mesh().face_number() // 2)
        ms.meshing_decimation_quadric_edge_collapse_with_texture(
            targetfacenum=alvo, qualitythr=0.4, extratcoordw=1.0, preserveboundary=True,
            boundaryweight=1.5, optimalplacement=True, preservenormal=True, planarquadric=True)
    m = ms.current_mesh()
    print("lod", i, m.vertex_number(), "vértices", m.face_number(), "faces")
    ms.save_current_mesh(d + "/lod%d.obj" % i, save_vertex_normal=False, save_wedge_texcoord=True,
                         save_vertex_color=False, save_textures=False)
