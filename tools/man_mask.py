# Máscara da roupa do personagem (models/man_mask.png): R = jaqueta, G = calça.
# O shader troca a cor dessas partes pela do jogador mantendo o desenho do tecido.
# Também gera models/man_albedo.png (textura de cor reduzida pra 1024).
# Uso: python3 tools/man_mask.py
import colorsys
from PIL import Image, ImageFilter

src = Image.open("models_src/man/man_0.png").convert("RGB")
src.resize((1024, 1024), Image.LANCZOS).save("models/man_albedo.png")
im = src.resize((512, 512), Image.LANCZOS)
jk = Image.new("L", im.size)
jn = Image.new("L", im.size)
pj, pn = jk.load(), jn.load()
px = im.load()
acc = {"j": [0.0, 0.0, 0.0, 0], "n": [0.0, 0.0, 0.0, 0]}


def lin(v):
    v /= 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


for y in range(im.size[1]):
    for x in range(im.size[0]):
        r, g, b = px[x, y]
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        k = None
        if 0.11 <= h <= 0.3 and s > 0.12 and v < 0.8:
            pj[x, y] = 255
            k = "j"
        elif 0.5 <= h <= 0.72 and s > 0.08 and v < 0.85:
            pn[x, y] = 255
            k = "n"
        if k:
            a = acc[k]
            a[0] += lin(r); a[1] += lin(g); a[2] += lin(b); a[3] += 1
# fecha buraquinhos (vincos escuros do tecido) e suaviza a borda
jk = jk.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(0.8))
jn = jn.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(0.8))
Image.merge("RGB", (jk, jn, Image.new("L", im.size))).save("models/man_mask.png")
for k, a in acc.items():
    print(k, "média linear", [round(c / a[3], 4) for c in a[:3]], "pixels", a[3])
