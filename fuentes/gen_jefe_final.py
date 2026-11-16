"""Jefe final (hombre de traje con bigote) y sus guardaespaldas (agentes), a partir de las poses del equipo.

Uso (desde fuentes/):  python3 gen_jefe_final.py
Entrada: fuentes/jefe_final/jefe.jpg y agentes.jpg (fondo gris liso). Se recortan solos y se guardan
         los recortes HD en fuentes/jefe_final/*_hd.png.
Salida:  sprites/enemigos/tesorero_16px.png (el jefe final) y agente_1/2/3_16px.png,
         hojas de 512x288 = 8 columnas x 6 filas de cuadros de 64x48, pies en (32, 45), mirando a la derecha.
         Filas: quieto 4 · caminar 6 · guardia 6 · ataque 7 (pegan en los cuadros 1 y 5) · golpe 1 · caída 6.

Como el equipo pasó UNA pose por personaje, las animaciones salen de esa pose:
  - caminar: las piernas se alternan (normal → juntas → en espejo) y el torso sube y baja 1 px
  - ataque (piña / tirar billetes): el torso se inclina para atrás (carga) y se tira para adelante
  - golpe: se inclina para atrás · caída: se va para atrás y queda acostado
Si el artista dibuja los cuadros a mano, misma grilla y listo.
"""
import os

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
CARPETA = os.path.join(AQUI, "jefe_final")
SALIDA = os.path.join(AQUI, "..", "sprites", "enemigos")
CW, CH, PIE_X, PIE_Y = 64, 48, 32, 45
OSCURO = (26, 16, 24)


# ------------------------------------------------------------------ recorte del fondo gris
def sin_fondo(path):
    a = np.array(Image.open(path).convert("RGB")).astype(int)
    fondo = np.median(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]), axis=0)
    parecido = np.abs(a - fondo).sum(2) < 40
    lab, _ = ndimage.label(parecido)
    bordes = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    adentro = ndimage.binary_opening(~np.isin(lab, list(bordes)), iterations=2)
    return np.dstack([a, adentro * 255]).astype(np.uint8), adentro


def personajes(rgba, mask, minimo=2000):
    lab, n = ndimage.label(mask)
    objs = ndimage.find_objects(lab)
    tam = ndimage.sum(mask, lab, range(1, n + 1))
    lista = sorted([(objs[i], i + 1) for i in range(n) if tam[i] > minimo], key=lambda t: t[0][1].start)
    res = []
    for sl, idx in lista:
        sub = rgba[sl].copy()
        sub[..., 3] = np.where(lab[sl] == idx, sub[..., 3], 0)
        res.append(sub)
    return res


# ------------------------------------------------------------------ a la escala del juego (16px)
def a_escala(rgba, alto):
    im = Image.fromarray(rgba, "RGBA")
    w = round(im.width * alto / im.height)
    a = np.array(im).astype(float)
    al = a[..., 3:] / 255
    pm = Image.fromarray(np.dstack([a[..., :3] * al, a[..., 3:]]).astype(np.uint8), "RGBA")
    ch = np.array(pm.resize((w, alto), Image.BOX)).astype(float)
    alfa = ch[..., 3]
    rgb = np.clip(ch[..., :3] / np.maximum(alfa[..., None] / 255, 1e-3), 0, 255).astype(np.uint8)
    m = alfa > 100
    img = Image.fromarray(rgb).filter(ImageFilter.UnsharpMask(radius=1, percent=80, threshold=2))
    img = img.quantize(colors=32, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.array(img), m * 255]).astype(np.uint8)
    borde = m & ~ndimage.binary_erosion(m)
    out[borde, :3] = np.minimum(out[borde, :3], (60, 50, 60))
    return out


# ------------------------------------------------------------------ armado de cuadros
class Pose:
    """Un personaje a escala del juego, partido en torso y piernas."""

    def __init__(self, arr, cadera=0.56):
        self.a = arr
        self.h, self.w = arr.shape[:2]
        self.cadera = int(self.h * cadera)
        op = arr[..., 3] > 0
        filas = np.where(op[-3:].any(0))[0]
        self.pie_x = (filas.min() + filas.max()) / 2.0      # centro de los pies

    def piernas(self, modo):
        p = self.a[self.cadera:].copy()
        cols = np.where((p[..., 3] > 0).any(0))[0]
        x0, x1 = cols.min(), cols.max() + 1
        recorte = Image.fromarray(p[:, x0:x1])
        if modo == "espejo":
            recorte = recorte.transpose(Image.FLIP_LEFT_RIGHT)
        elif modo == "juntas":
            nw = max(4, int(recorte.width * 0.62))
            recorte = recorte.resize((nw, recorte.height), Image.NEAREST)
        lienzo = Image.new("RGBA", (self.w, p.shape[0]))
        centro = (x0 + x1) / 2.0
        lienzo.alpha_composite(recorte, (int(round(centro - recorte.width / 2.0)), 0))
        return lienzo

    def torso(self, inclinar):
        t = Image.fromarray(self.a[:self.cadera].copy())
        if inclinar:
            # inclinación: arriba se corre más que abajo (cabeza adelante / atrás)
            pad = 12
            ancho = Image.new("RGBA", (t.width + pad * 2, t.height))
            ancho.alpha_composite(t, (pad, 0))
            k = inclinar
            ancho = ancho.transform(ancho.size, Image.AFFINE, (1, k, -k * t.height, 0, 1, 0), Image.NEAREST)
            return ancho, pad
        return t, 0

    def cuadro(self, inclinar=0.0, dx=0, dy_torso=0, piernas="normal", giro=0.0, baja=0):
        img = Image.new("RGBA", (self.w + 40, self.h + 4))
        base_x = 20
        img.alpha_composite(self.piernas(piernas), (base_x, self.cadera + 2))
        t, pad = self.torso(inclinar)
        img.alpha_composite(t, (base_x - pad, dy_torso + 2))
        pie_x = base_x + self.pie_x
        pie_y = self.h + 2
        if giro:
            # se cae para atrás girando alrededor de la cintura, y apoya en el piso
            cx, cy = pie_x, pie_y - self.h * 0.5
            grande = Image.new("RGBA", (img.width + 80, img.height + 80))
            grande.alpha_composite(img, (40, 40))
            grande = grande.rotate(giro, resample=Image.NEAREST, center=(cx + 40, cy + 40))
            arr = np.array(grande)
            filas = np.where((arr[..., 3] > 0).any(1))[0]
            abajo = filas.max()
            img = grande
            pie_x = cx + 40
            pie_y = abajo + 1
        out = Image.new("RGBA", (CW, CH))
        out.alpha_composite(img, (int(round(PIE_X + dx - pie_x)), int(round(PIE_Y + 1 + baja - pie_y))))
        return out


def hoja(pose):
    filas = [
        # quieto: respira (el torso baja 1 px)
        [pose.cuadro(dy_torso=d) for d in (0, 0, 1, 1)],
        # caminar
        [pose.cuadro(piernas=p, dy_torso=d) for p, d in
         (("normal", 0), ("normal", 1), ("juntas", 0), ("espejo", 0), ("espejo", 1), ("juntas", 0))],
        # guardia (avanzar en guardia: igual, un poco inclinado adelante)
        [pose.cuadro(piernas=p, dy_torso=d, inclinar=0.06) for p, d in
         (("normal", 0), ("normal", 1), ("juntas", 0), ("espejo", 0), ("espejo", 1), ("juntas", 0))],
        # ataque: carga, golpe (1), sostiene, vuelve, carga, golpe (5), vuelve
        [pose.cuadro(inclinar=-0.12, dx=-1), pose.cuadro(inclinar=0.24, dx=2), pose.cuadro(inclinar=0.16, dx=1),
         pose.cuadro(), pose.cuadro(inclinar=-0.12, dx=-1), pose.cuadro(inclinar=0.27, dx=3),
         pose.cuadro(inclinar=0.05)],
        # golpe recibido
        [pose.cuadro(inclinar=-0.22, dx=-2)],
        # caída: para atrás y queda acostado
        [pose.cuadro(inclinar=-0.3, dx=-2), pose.cuadro(giro=30), pose.cuadro(giro=60), pose.cuadro(giro=88),
         pose.cuadro(giro=90, baja=-1), pose.cuadro(giro=90)],
    ]
    out = Image.new("RGBA", (CW * 8, CH * 6))
    for f, cuadros in enumerate(filas):
        for k, c in enumerate(cuadros):
            out.alpha_composite(c, (k * CW, f * CH))
    return out


def generar():
    rgba, m = sin_fondo(os.path.join(CARPETA, "jefe.jpg"))
    jefe = personajes(rgba, m)[0]
    Image.fromarray(jefe).save(os.path.join(CARPETA, "jefe_hd.png"))
    rgba, m = sin_fondo(os.path.join(CARPETA, "agentes.jpg"))
    agentes = personajes(rgba, m)
    for i, a in enumerate(agentes):
        Image.fromarray(a).save(os.path.join(CARPETA, f"agente_{i + 1}_hd.png"))

    hoja(Pose(a_escala(jefe, 44), 0.55)).save(os.path.join(SALIDA, "tesorero_16px.png"))
    for i, (a, alto) in enumerate(zip(agentes, (40, 38, 40))):
        hoja(Pose(a_escala(a, alto), 0.56)).save(os.path.join(SALIDA, f"agente_{i + 1}_16px.png"))
    print("listo")


if __name__ == "__main__":
    generar()
