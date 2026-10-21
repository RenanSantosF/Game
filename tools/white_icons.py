# Gera os ícones brancos (silhueta com leve sombreado) das armas e o punho estilizado.
# Uso: python3 tools/white_icons.py   (depois de tools/make_icons.gd)
import os
from PIL import Image, ImageDraw, ImageFilter

GUNS = ["glock", "deagle", "mp5", "ump45", "m4a1", "scar", "ak47", "r870", "m1014", "kar98", "awm"]
root = os.path.join(os.path.dirname(__file__), "..", "icons")

for g in GUNS:
    im = Image.open(os.path.join(root, g + ".png")).convert("RGBA")
    px = im.load()
    out = Image.new("RGBA", im.size)
    po = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, gg, b, a = px[x, y]
            if a < 8:
                continue
            l = (r * 0.3 + gg * 0.59 + b * 0.11) / 255.0
            v = int(255 * (0.78 + 0.22 * min(1.0, l * 1.6)))
            po[x, y] = (v, v, v, 255 if a > 100 else a)
    # contorno escuro fino pra ler em cima de qualquer fundo
    sh = out.split()[3].filter(ImageFilter.MaxFilter(5))
    base = Image.new("RGBA", im.size, (0, 0, 0, 0))
    base.putalpha(sh.point(lambda v: int(v * 0.55)))
    base.alpha_composite(out)
    base.save(os.path.join(root, "w_" + g + ".png"))

# punho fechado estilizado (desenho simples, branco)
S = 4
W, H = 256 * S, 128 * S
im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
cx, cy = W // 2, H // 2 + 6 * S
white = (245, 245, 245, 255)
# dedos (4 gomos arredondados)
for i in range(4):
    x0 = cx - 46 * S + i * 23 * S
    d.rounded_rectangle([x0, cy - 40 * S, x0 + 22 * S, cy - 4 * S], radius=10 * S, fill=white)
# palma
d.rounded_rectangle([cx - 46 * S, cy - 18 * S, cx + 46 * S, cy + 34 * S], radius=14 * S, fill=white)
# polegar por cima dos dedos
d.rounded_rectangle([cx - 44 * S, cy - 6 * S, cx + 6 * S, cy + 12 * S], radius=9 * S, fill=(205, 205, 205, 255))
# punho/pulso
d.rounded_rectangle([cx - 30 * S, cy + 28 * S, cx + 34 * S, cy + 50 * S], radius=6 * S, fill=white)
# vincos
for i in range(1, 4):
    x = cx - 46 * S + i * 23 * S
    d.line([x, cy - 34 * S, x, cy - 12 * S], fill=(170, 170, 170, 255), width=2 * S)
im = im.resize((256, 128), Image.LANCZOS)
sh = im.split()[3].filter(ImageFilter.MaxFilter(5))
base = Image.new("RGBA", im.size, (0, 0, 0, 0))
base.putalpha(sh.point(lambda v: int(v * 0.55)))
base.alpha_composite(im)
base.save(os.path.join(root, "w_fist.png"))
print("ok")
