"""Dibuja la ROTONDA DEL CHACHO (entrada de la ciudad de La Rioja) para la intro del juego.

Uso (desde fuentes/):  python3 gen_rotonda.py
Escribe en ../sprites/fondos/:
  rotonda_noche.png      240x135  (intro: la estatua cobra vida)
  rotonda_amanecer.png   240x135  (para el final de la historia: vuelve al pedestal)
y en ../sprites/estatua_chacho.png la estatua grande (el Chacho al doble, con Scale2x).

Mismo método que los otros escenarios: se dibuja a 480x270 con colores planos y se pasa a la
grilla de 16px con a_16px.py. El pedestal (roca rojiza tallada) va en el fondo; la estatua es un
sprite aparte para poder animarla.

Referencias del monumento: estatua del Chacho de pie, con la lanza en diagonal sobre el hombro y el
brazo señalando; pedestal de roca rojiza irregular sobre un montículo de pasto; en el centro de la
rotonda de la entrada a la capital, con la Sierra de Velasco atrás, guardarrail y faroles altos.
"""
import math
import os
import random

from PIL import Image, ImageDraw

from a_16px import a_16px

AQUI = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(AQUI, "..", "sprites")
W, H = 480, 270

PALETAS = {
    "noche": {
        "cielo": [(14, 16, 42), (20, 22, 56), (28, 28, 70), (38, 34, 84), (52, 40, 96), (70, 48, 104)],
        "lejos": (44, 40, 86), "lejos_luz": (58, 52, 104),
        "cerca": (30, 30, 62), "cerca_luz": (42, 40, 78),
        "pasto": (40, 70, 50), "pasto_luz": (56, 92, 58), "pasto_osc": (28, 50, 40),
        "asfalto": (40, 40, 48), "asfalto_luz": (54, 54, 62), "linea": (150, 136, 80),
        "metal": (96, 102, 120), "metal_osc": (60, 64, 80),
        "roca": (112, 52, 44), "roca_luz": (146, 74, 58), "roca_osc": (76, 34, 34), "roca_borde": (46, 20, 24),
        "poste": (30, 30, 40), "luz": (255, 214, 140), "halo": (120, 96, 80),
        "estrellas": True, "luna": True,
    },
    "amanecer": {
        "cielo": [(92, 128, 196), (124, 150, 204), (170, 168, 200), (220, 182, 180), (246, 196, 150), (252, 214, 150)],
        "lejos": (126, 120, 150), "lejos_luz": (150, 140, 164),
        "cerca": (96, 92, 124), "cerca_luz": (118, 108, 136),
        "pasto": (118, 150, 70), "pasto_luz": (150, 176, 84), "pasto_osc": (86, 118, 58),
        "asfalto": (72, 72, 80), "asfalto_luz": (92, 92, 100), "linea": (214, 196, 110),
        "metal": (176, 180, 190), "metal_osc": (120, 124, 138),
        "roca": (168, 82, 58), "roca_luz": (206, 116, 80), "roca_osc": (122, 56, 44), "roca_borde": (70, 30, 28),
        "poste": (60, 62, 72), "luz": None, "halo": None,
        "estrellas": False, "luna": False,
    },
}

# El pedestal en coordenadas de 480x270 (en el juego: la mitad)
PED_X0, PED_X1 = 104, 220      # base
PED_TOPE_Y = 146               # donde apoyan los pies de la estatua (en el juego y = 73)
PED_BASE_Y = 226


def cielo(d, p):
    bandas = p["cielo"]
    alto = 200
    paso = alto / len(bandas)
    for i, c in enumerate(bandas):
        y0 = int(i * paso)
        d.rectangle((0, y0, W, int((i + 1) * paso) + 1), fill=c)
        # borde "aserrado" de 2 px entre franjas, como en los otros fondos
        if i > 0:
            for x in range(0, W, 4):
                d.rectangle((x, y0 - 2, x + 1, y0 - 1), fill=c)
    if p["estrellas"]:
        rng = random.Random(3)
        for _ in range(70):
            x, y = rng.randrange(W), rng.randrange(0, 120)
            c = (230, 230, 255) if rng.random() < 0.3 else (160, 160, 210)
            d.rectangle((x, y, x + 1, y + 1), fill=c)
    if p["luna"]:
        d.ellipse((380, 26, 412, 58), fill=(236, 232, 210))
        d.ellipse((372, 22, 404, 54), fill=p["cielo"][0])   # luna menguante


def sierra(d, p, base_y, alto, semilla, color, luz, rugosidad):
    rng = random.Random(semilla)
    pts = [(0, base_y)]
    y = base_y - alto * 0.6
    for x in range(0, W + 24, 24):
        y = max(base_y - alto, min(base_y - alto * 0.3, y + rng.randint(-rugosidad, rugosidad)))
        pts.append((x, int(y)))
    pts.append((W, base_y))
    d.polygon(pts, fill=color)
    # filo iluminado de las cumbres
    for (x0, y0), (x1, y1) in zip(pts[1:-2], pts[2:-1]):
        d.line((x0, y0, x1, y1), fill=luz, width=2)


def guardarrail_y_ruta(d, p):
    # avenida de atrás
    d.rectangle((0, 192, W, 210), fill=p["asfalto"])
    for x in range(0, W, 28):
        d.rectangle((x, 200, x + 13, 201), fill=p["linea"])
    # guardarrail
    d.rectangle((0, 184, W, 189), fill=p["metal"])
    d.rectangle((0, 189, W, 190), fill=p["metal_osc"])
    for x in range(6, W, 30):
        d.rectangle((x, 184, x + 3, 194), fill=p["metal_osc"])


def faroles(d, p):
    for x in (34, 300, 446):
        d.rectangle((x, 96, x + 3, 192), fill=p["poste"])
        # brazo doble
        d.rectangle((x - 16, 96, x + 19, 98), fill=p["poste"])
        for lx in (x - 18, x + 17):
            d.rectangle((lx, 98, lx + 5, 101), fill=p["poste"])
            if p["luz"]:
                d.rectangle((lx + 1, 101, lx + 4, 103), fill=p["luz"])
                d.rectangle((lx - 1, 104, lx + 6, 105), fill=p["halo"])
    # cables
    for y0 in (110, 118):
        d.line((0, y0, W, y0 + 6), fill=p["metal_osc"], width=1)


def pasto(d, p):
    # montículo de la rotonda
    d.rectangle((0, 206, W, H), fill=p["pasto"])
    # cordón de la rotonda
    d.rectangle((0, 204, W, 207), fill=p["metal"])
    rng = random.Random(9)
    for _ in range(520):
        x, y = rng.randrange(W), rng.randrange(210, H)
        c = p["pasto_luz"] if rng.random() < 0.5 else p["pasto_osc"]
        d.rectangle((x, y, x + 1, y + 3), fill=c)   # matas de pasto


def pedestal(d, p):
    """Roca rojiza tallada: facetas planas, más ancha abajo y tope plano."""
    cx = (PED_X0 + PED_X1) // 2
    silueta = [(PED_X0, PED_BASE_Y), (PED_X0 + 4, 212), (PED_X0 + 16, 198), (PED_X0 + 14, 182), (PED_X0 + 22, 168),
               (cx - 34, PED_TOPE_Y + 6), (cx - 26, PED_TOPE_Y), (cx + 30, PED_TOPE_Y), (cx + 40, PED_TOPE_Y + 8),
               (PED_X1 - 16, 172), (PED_X1 - 12, 190), (PED_X1 - 2, 206), (PED_X1 + 4, 218), (PED_X1, PED_BASE_Y)]
    d.polygon(silueta, fill=p["roca"])
    # facetas: luz a la izquierda (como en la foto), sombra a la derecha
    d.polygon([(PED_X0 + 16, 198), (PED_X0 + 14, 182), (PED_X0 + 22, 168), (cx - 34, PED_TOPE_Y + 6), (cx - 20, 170),
               (cx - 24, 196), (PED_X0 + 4, 212)], fill=p["roca_luz"])
    d.polygon([(cx + 12, 164), (cx + 40, PED_TOPE_Y + 8), (PED_X1 - 16, 172), (PED_X1 - 12, 190), (PED_X1 - 2, 206),
               (PED_X1 + 4, 218), (PED_X1, PED_BASE_Y), (cx + 22, PED_BASE_Y), (cx + 16, 196)], fill=p["roca_osc"])
    d.polygon([(PED_X0 + 4, 212), (cx - 24, 196), (cx - 10, 214), (cx - 34, PED_BASE_Y), (PED_X0, PED_BASE_Y)],
              fill=p["roca"])
    # vetas y grietas
    for (x0, y0, x1, y1) in [(cx - 8, 170, cx - 2, 196), (cx + 18, 184, cx + 26, 210), (PED_X0 + 24, 200, PED_X0 + 34, 218),
                             (cx - 26, PED_TOPE_Y + 10, cx - 14, PED_TOPE_Y + 18), (cx + 4, 200, cx + 10, 222)]:
        d.line((x0, y0, x1, y1), fill=p["roca_borde"], width=2)
    # tope plano (donde apoya la estatua)
    d.rectangle((cx - 30, PED_TOPE_Y, cx + 34, PED_TOPE_Y + 2), fill=p["roca_luz"])
    # contorno
    d.line(silueta + [silueta[0]], fill=p["roca_borde"], width=2)
    # sombra en el pasto
    d.ellipse((PED_X0 - 10, PED_BASE_Y - 6, PED_X1 + 14, PED_BASE_Y + 8), fill=p["pasto_osc"])
    d.polygon(silueta[:1] + [(PED_X1, PED_BASE_Y)], fill=p["roca_osc"])


def escena(nombre):
    p = PALETAS[nombre]
    im = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(im)
    cielo(d, p)
    sierra(d, p, 196, 110, 5, p["lejos"], p["lejos_luz"], 14)     # Sierra de Velasco (lejos)
    sierra(d, p, 196, 64, 8, p["cerca"], p["cerca_luz"], 10)      # cerros más cerca
    faroles(d, p)
    guardarrail_y_ruta(d, p)
    pasto(d, p)
    pedestal(d, p)
    # el pedestal tapa el pasto del frente: se redibuja la sombra arriba del pasto
    return a_16px(im).convert("RGB")


# ---------------------------------------------------------------- estatua (Scale2x)
def scale2x(img):
    """Escalado EPX/Scale2x: duplica el tamaño suavizando las diagonales sin inventar colores."""
    src = img.load()
    w, h = img.size
    out = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    o = out.load()

    def px(x, y):
        x = min(max(x, 0), w - 1)
        y = min(max(y, 0), h - 1)
        return src[x, y]

    for y in range(h):
        for x in range(w):
            p = px(x, y)
            a, b, c, dd = px(x, y - 1), px(x + 1, y), px(x - 1, y), px(x, y + 1)
            e0 = a if (c == a and c != dd and a != b) else p
            e1 = b if (a == b and a != c and b != dd) else p
            e2 = c if (dd == c and dd != b and c != a) else p
            e3 = b if (b == dd and b != a and dd != c) else p
            o[2 * x, 2 * y] = e0
            o[2 * x + 1, 2 * y] = e1
            o[2 * x, 2 * y + 1] = e2
            o[2 * x + 1, 2 * y + 1] = e3
    return out


def estatua():
    hoja = Image.open(os.path.join(SPRITES, "chacho_spritesheet.png")).convert("RGBA")
    cuadro = hoja.crop((1 * 54, 1 * 41, 2 * 54, 2 * 41))   # caminar, cuadro 1: parado, lanza en diagonal al hombro
    grande = scale2x(cuadro)
    grande.save(os.path.join(SPRITES, "estatua_chacho.png"))
    print("estatua", grande.size)


if __name__ == "__main__":
    for nombre in PALETAS:
        img = escena(nombre)
        img.save(os.path.join(SPRITES, "fondos", f"rotonda_{nombre}.png"))
        print(nombre, img.size)
    estatua()
