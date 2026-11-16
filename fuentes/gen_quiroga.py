"""Arma la hoja de sprites de FACUNDO QUIROGA (personaje jugable 2) a partir del Marinero.

Uso (desde fuentes/):  python3 gen_quiroga.py
Lee ../sprites/enemigos/marinero_16px.png y escribe ../sprites/quiroga_16px.png (misma grilla:
8 columnas x 6 filas de 64x48, pies en (32, 45)).

Rasgos del retrato que se mantienen (propuesta del equipo):
  - melena negra enrulada con volumen y patillas (en lugar de la galera)
  - saco de general azul verdoso oscuro, charreteras y bordado dorado en el pecho
  - cuello y puños dorados, faja dorada en la cintura
  - pantalón rojo
  - sable (el del Marinero)
Los cuadros de la caída donde está acostado se giran 90°, se pintan "parado" y se vuelven a girar.
"""
import colorsys
import os

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ENTRADA = os.path.join(AQUI, "..", "sprites", "enemigos", "marinero_16px.png")
SALIDA = os.path.join(AQUI, "..", "sprites", "quiroga_16px.png")
CW, CH = 64, 48
CUADROS = [4, 6, 6, 7, 1, 6]          # cuadros por fila (quieto, caminar, guardia, ataque, golpe, caida)
ACOSTADO = {(5, 1), (5, 2), (5, 3), (5, 4), (5, 5)}   # (fila, columna) con la cabeza a la izquierda

PELO = [(14, 10, 12), (24, 16, 18), (38, 26, 24), (20, 13, 15)]
DORADO = [(236, 196, 92), (204, 156, 62), (150, 104, 40)]


def hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)


def rgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h, max(0, min(1, s)), max(0, min(1, v)))
    return (round(r * 255), round(g * 255), round(b * 255))


def es_plata(c):   # hoja del sable / correaje blanco
    h, s, v = hsv(c)
    return v > 0.62 and s < 0.25


def es_azul(c):
    h, s, v = hsv(c)
    return 0.53 < h < 0.72 and s > 0.15 and v > 0.12


def es_rojo(c):
    h, s, v = hsv(c)
    return (h < 0.05 or h > 0.93) and s > 0.45 and v > 0.35


def dorado(v):
    return DORADO[0] if v > 0.62 else (DORADO[1] if v > 0.38 else DORADO[2])


def pintar(cuadro):
    a = np.array(cuadro)
    op = a[..., 3] > 0
    H, W = op.shape
    col = lambda y, x: tuple(int(v) for v in a[y, x, :3])
    azules = [(y, x) for y in range(H) for x in range(W) if op[y, x] and es_azul(col(y, x))]
    if not azules:
        return cuadro
    tx = int(np.median([x for _, x in azules]))

    # --- 1) cabeza: primera fila (de arriba) con 4+ píxeles seguidos que no son plata
    y_top, cx = None, tx
    for y in range(H):
        mejor, ini, run = 0, None, 0
        for x in range(max(0, tx - 9), min(W, tx + 10)):
            if op[y, x] and not es_plata(col(y, x)):
                run += 1
                if run > mejor:
                    mejor, ini = run, x - run + 1
            else:
                run = 0
        if mejor >= 4:   # el ala de la galera (el sable mide 1-2 px)
            y_top, cx = y, ini + mejor // 2
            break
    if y_top is None:
        return cuadro

    # --- 2) sacar la galera (copa + ala + escarapela)
    for y in range(max(0, y_top - 6), y_top + 2):
        for x in range(max(0, cx - 4), min(W, cx + 5)):
            if op[y, x] and not es_plata(col(y, x)):
                a[y, x, 3] = 0
    op = a[..., 3] > 0

    # --- 3) cinturón: fila con más plata entre los azules (la faja)
    filas_azul = sorted({y for y, _ in azules})
    cint_y, mejor = None, 0
    for y in filas_azul:
        if not (y_top + 12 <= y <= y_top + 24):
            continue
        n = sum(1 for x in range(max(0, tx - 7), min(W, tx + 8)) if op[y, x] and es_plata(col(y, x)))
        if n > mejor:
            cint_y, mejor = y, n
    if cint_y is None or mejor < 2:
        cint_y = y_top + 17

    # --- 3b) cara más clara (el Marinero la tenía en sombra bajo el ala)
    for y in range(y_top + 2, y_top + 8):
        for x in range(max(0, cx - 2), min(W, cx + 4)):
            if op[y, x]:
                h, s_, v = hsv(col(y, x))
                if (h < 0.12 or h > 0.92) and 0.12 < v < 0.62 and s_ > 0.15:
                    a[y, x, :3] = rgb(0.06, 0.38, min(0.9, v * 1.55 + 0.12))

    # --- 4) colores del uniforme
    hombro_y = None
    for y in range(H):
        for x in range(W):
            if not op[y, x]:
                continue
            c = col(y, x)
            h, s, v = hsv(c)
            if es_azul(c):
                if y > cint_y + 1:      # pantalón rojo
                    a[y, x, :3] = rgb(0.985, 0.72, min(1.0, v * 1.35 + 0.08))
                else:                   # saco azul verdoso oscuro
                    a[y, x, :3] = rgb(0.52, 0.42, v * 0.92)
                    if hombro_y is None and y > y_top + 6:
                        hombro_y = y
            elif es_rojo(c) and y <= cint_y + 1:    # cuello y puños
                a[y, x, :3] = dorado(v)
            elif es_plata(c) and abs(y - cint_y) <= 1 and abs(x - tx) <= 7:   # faja
                a[y, x, :3] = dorado(v + 0.1)

    # --- 5) charreteras y bordado del pecho
    if hombro_y is not None:
        for y in (hombro_y, hombro_y + 1):
            xs = [x for x in range(W) if op[y, x] and es_azul(col(y, x)) is False and hsv(col(y, x))[0] > 0.45
                  and hsv(col(y, x))[0] < 0.6 and hsv(col(y, x))[1] > 0.2]
            fila = [x for x in range(max(0, tx - 9), min(W, tx + 10)) if op[y, x]]
            if len(fila) >= 6:
                for x in (fila[0], fila[0] + 1, fila[-1] - 1, fila[-1]):
                    a[y, x, :3] = DORADO[0] if y == hombro_y else DORADO[1]
        for y in range(hombro_y + 2, cint_y - 1):
            for x in (tx, tx + 1):
                if op[y, x] and (y + x) % 2 == 0 and hsv(col(y, x))[2] < 0.5:
                    a[y, x, :3] = DORADO[1]

    # --- 6) melena: arriba de la cabeza, atrás (izquierda) y patilla adelante
    pelo = set()
    for dy, (x0, x1) in {-1: (-3, 2), 0: (-4, 3), 1: (-5, 4), 2: (-5, 4)}.items():
        for dx in range(x0, x1 + 1):
            pelo.add((y_top + dy, cx + dx))
    for dy in range(3, 9):
        for dx in ((-5, -4, -3) if dy < 7 else (-4, -3)):
            pelo.add((y_top + dy, cx + dx))
    for dy in (3, 4, 5):
        pelo.add((y_top + dy, cx + 4))
    for (y, x) in pelo:
        if 0 <= y < H and 0 <= x < W:
            if op[y, x] and es_plata(col(y, x)):
                continue
            k = (x * 7 + y * 3) % 9
            c = PELO[1]
            if k in (0, 4):
                c = PELO[2]      # rulos con brillo
            elif k == 2:
                c = PELO[0]
            a[y, x, :3] = c
            a[y, x, 3] = 255
    # contorno oscuro de la melena
    op = a[..., 3] > 0
    for (y, x) in list(pelo):
        for dy, dx in ((-1, 0), (0, -1), (0, 1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < H and 0 <= xx < W and not op[yy, xx] and (yy, xx) not in pelo:
                if (y + x) % 3 != 0:     # borde irregular: rulos
                    a[yy, xx] = (*PELO[0], 255)
    return Image.fromarray(a, "RGBA")


def main():
    hoja = Image.open(ENTRADA).convert("RGBA")
    salida = Image.new("RGBA", hoja.size, (0, 0, 0, 0))
    for fila, n in enumerate(CUADROS):
        for c in range(n):
            cuadro = hoja.crop((c * CW, fila * CH, c * CW + CW, fila * CH + CH))
            if (fila, c) in ACOSTADO:
                # cabeza a la izquierda -> girar para que quede "parado", pintar y volver
                g = Image.new("RGBA", (CH + 16, CW), (0, 0, 0, 0))
                g.paste(cuadro.rotate(-90, expand=True), (8, 0))
                g = pintar(g)
                cuadro = g.crop((8, 0, 8 + CH, CW)).rotate(90, expand=True)
            else:
                cuadro = pintar(cuadro)
            salida.paste(cuadro, (c * CW, fila * CH))
    salida.save(SALIDA)
    print("quiroga", salida.size)


if __name__ == "__main__":
    main()
