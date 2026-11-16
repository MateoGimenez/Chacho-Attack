"""Pasa a 16px los sprites del juego que todavia estaban en la version v2.

Uso (desde la carpeta fuentes/):  python3 gen_16px.py
Necesita: Pillow y numpy.

  - chacho_spritesheet_v2.png (cuadros de 108x81) -> sprites/chacho_spritesheet.png (cuadros de 54x41)
    Como 81 es impar, a cada cuadro se le agrega 1 px transparente abajo antes de convertirlo.
  - barril_v2.png (cuadros de 40x40) -> sprites/barril.png (cuadros de 20x20)
  - botones del celular: se redibujan en pixel art (24 px, la lanza 28 px) con el texto
    en una fuente pixel de 3x5, porque la fuente normal no entra en un boton tan chico.

Si el artista redibuja al Chacho directamente en 16px, guardalo como
sprites/chacho_spritesheet.png con cuadros de 54x41 y no hace falta correr esto.
"""
import os
from collections import Counter

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(AQUI, "..", "sprites")


def a_16px_personaje(img):
    """Como a_16px.py pero pensado para personajes con fondo transparente:
    - un pixel queda opaco si en el bloque de 2x2 hay al menos 2 opacos (silueta sólida, sin "pelusa")
    - gana el color más repetido; en empate, el más OSCURO (así sobrevive el contorno).
    Se probó contra a_16px.py (empate = color más raro) y este queda más limpio en el Chacho."""
    a = np.array(img.convert("RGBA"))
    h, w = a.shape[0] // 2, a.shape[1] // 2
    out = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            opacos = [tuple(p) for p in a[2 * y:2 * y + 2, 2 * x:2 * x + 2].reshape(4, 4) if p[3] > 0]
            if len(opacos) < 2:
                continue
            c = Counter(opacos)
            out[y, x] = max(c, key=lambda k: (c[k], -(k[0] * 0.3 + k[1] * 0.59 + k[2] * 0.11)))
    return Image.fromarray(out, "RGBA")


def chacho():
    hoja = Image.open(os.path.join(AQUI, "chacho_spritesheet_v2.png")).convert("RGBA")
    cw, ch = 108, 81
    cols, filas = hoja.width // cw, hoja.height // ch
    salida = Image.new("RGBA", (cols * 54, filas * 41), (0, 0, 0, 0))
    for f in range(filas):
        for c in range(cols):
            cuadro = Image.new("RGBA", (108, 82), (0, 0, 0, 0))
            cuadro.paste(hoja.crop((c * cw, f * ch, c * cw + cw, f * ch + ch)), (0, 0))
            salida.paste(a_16px_personaje(cuadro), (c * 54, f * 41))
    salida.save(os.path.join(SPRITES, "chacho_spritesheet.png"))
    print("chacho", salida.size)


def barril():
    hoja = Image.open(os.path.join(AQUI, "barril_v2.png")).convert("RGBA")
    salida = Image.new("RGBA", (hoja.width // 2, hoja.height // 2), (0, 0, 0, 0))
    for c in range(hoja.width // 40):
        salida.paste(a_16px_personaje(hoja.crop((c * 40, 0, c * 40 + 40, 40))), (c * 20, 0))
    salida.save(os.path.join(SPRITES, "barril.png"))
    print("barril", salida.size)


# ---------------------------------------------------------------- botones
F3 = {  # fuente pixel 3x5
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"],
    "E": ["111", "100", "110", "100", "111"],
    "I": ["111", "010", "010", "010", "111"],
    "L": ["100", "100", "100", "100", "111"],
    "N": ["101", "111", "111", "111", "101"],
    "O": ["010", "101", "101", "101", "010"],
    "Q": ["010", "101", "101", "110", "011"],
    "R": ["110", "101", "110", "101", "101"],
    "Z": ["111", "001", "010", "100", "111"],
}

BORDE = (26, 15, 20, 230)
LUZ = (255, 241, 214, 170)
TEXTO = (255, 241, 214, 255)
SOMBRA_TEXTO = (26, 15, 20, 255)

BOTONES = {  # nombre: (diametro, color normal, color apretado, texto)
    "boton_lanza": (28, (199, 70, 51, 130), (249, 86, 62, 210), "LANZA"),
    "boton_bloqueo": (24, (70, 110, 170, 130), (86, 136, 211, 210), "BLOQ"),
    "boton_correr": (24, (189, 150, 59, 130), (237, 187, 75, 210), "CORRER"),
    "boton_poder": (24, (229, 221, 189, 130), (255, 255, 237, 210), "RABIA"),
}


def boton(d, relleno, texto):
    im = Image.new("RGBA", (d, d), (0, 0, 0, 0))
    r = d / 2
    for y in range(d):
        for x in range(d):
            dist = ((x + 0.5 - r) ** 2 + (y + 0.5 - r) ** 2) ** 0.5
            if dist <= r - 2:
                im.putpixel((x, y), relleno)
            elif dist <= r - 1:
                im.putpixel((x, y), LUZ)
            elif dist <= r:
                im.putpixel((x, y), BORDE)
    ancho = len(texto) * 4 - 1
    x0, y0 = (d - ancho) // 2, (d - 5) // 2
    for capa, color, dx in ((0, SOMBRA_TEXTO, 1), (1, TEXTO, 0)):
        for i, letra in enumerate(texto):
            for fy, fila in enumerate(F3[letra]):
                for fx, b in enumerate(fila):
                    if b == "1":
                        im.putpixel((x0 + i * 4 + fx + dx, y0 + fy + dx), color)
    return im


def botones():
    carpeta = os.path.join(SPRITES, "ui")
    os.makedirs(carpeta, exist_ok=True)
    for nombre, (d, normal, apretado, texto) in BOTONES.items():
        boton(d, normal, texto).save(os.path.join(carpeta, nombre + ".png"))
        boton(d, apretado, texto).save(os.path.join(carpeta, nombre + "_apretado.png"))
    print("botones", len(BOTONES) * 2)


if __name__ == "__main__":
    chacho()
    barril()
    botones()
