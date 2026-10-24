#!/usr/bin/env python3
"""Atlas em alta (4x4 camadas de 1024 px + borda de 32 px = 4224 px).

Camadas de construção e chão trocadas por fotos CC0 do Poly Haven (textures_src/photo, 1k);
as outras vêm do atlas procedural antigo (tools/gen_assets.py) aumentadas.
O brilho médio de cada foto é acertado pro da camada antiga (o jogo multiplica pela cor do
vértice, então o tom das casas e do chão continua o mesmo, só fica nítido e detalhado).
Uso: python3 tools/atlas_photo.py <atlas antigo 2176 px>
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLD_S, OLD_P = 512, 16
S, P = 1024, 32
T = S + 2 * P
# camada -> [foto, quanto tira de cor (0 = mantém, 1 = cinza), ganho de brilho extra]
PHOTOS = {
    0: ["rocky_terrain_02", 0.0, 1.0],     # grama
    1: ["brown_mud_leaves_01", 0.2, 1.0],  # terra
    4: ["painted_plaster_wall", 0.85, 1.0],  # reboco (a cor vem do tema da cidade)
    5: ["red_brick_03", 0.15, 1.0],        # tijolo
    6: ["roof_tiles_14", 0.55, 1.08],      # telha (a cor vem do tema)
    7: ["weathered_planks", 0.3, 1.1],     # madeira
    8: ["corrugated_iron_02", 0.6, 1.0],   # zinco
    9: ["concrete_wall_008", 0.7, 1.0],    # concreto
    10: ["asphalt_02", 0.5, 1.0],          # asfalto
}


def old_layer(atlas, i):
    ot = OLD_S + 2 * OLD_P
    x, y = (i % 4) * ot + OLD_P, (i // 4) * ot + OLD_P
    return atlas.crop((x, y, x + OLD_S, y + OLD_S))


def lum(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def main():
    old = Image.open(sys.argv[1]).convert("RGB")
    out = Image.new("RGB", (T * 4, T * 4))
    for i in range(16):
        ol = old_layer(old, i)
        if i in PHOTOS:
            name, desat, gain = PHOTOS[i]
            ph = Image.open(os.path.join(ROOT, "textures_src", "photo", name + ".jpg")).convert("RGB").resize((S, S), Image.LANCZOS)
            a = np.asarray(ph).astype(np.float32) / 255.0
            g = lum(a)[..., None]
            a = a * (1 - desat) + g * desat
            target = lum(np.asarray(ol).astype(np.float32) / 255.0).mean() * gain
            a = a * (target / max(lum(a).mean(), 1e-3))
            im = Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8))
        else:
            im = ol.resize((S, S), Image.LANCZOS)
        arr = np.pad(np.asarray(im), ((P, P), (P, P), (0, 0)), mode="wrap")
        out.paste(Image.fromarray(arr), ((i % 4) * T, (i // 4) * T))
        print("camada", i, PHOTOS.get(i, ["procedural"])[0])
    out.save(os.path.join(ROOT, "textures", "atlas2d.png"), optimize=True)
    print("ok", out.size)


if __name__ == "__main__":
    main()
