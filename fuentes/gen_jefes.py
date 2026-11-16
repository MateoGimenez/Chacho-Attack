"""Arte PROVISORIO de los jefes (v7). Uso (desde fuentes/):  python3 gen_jefes.py

1) Repintes de hojas que ya están en el juego (misma grilla 64x48, así heredan todas las animaciones):
     paz        <- quiroga   (saco azul de general, pantalón blanco, pelo castaño; conserva el dorado)
     rivadavia  <- artillero (levita negra, pantalón claro; el chacó queda como galera negra)
     rosas      <- marinero  (saco azul, pantalón y sombrero rojo punzó)
     (el jefe final y sus agentes salen de gen_jefe_final.py, con las poses que dibujó el equipo)
   Cuando el equipo termine el arte final, se reemplaza el PNG y listo (misma grilla).

2) Objetos y vehículos dibujados por código, en la grilla de 16px:
     caballeria.png  4 cuadros de 48x40 (cascos en y 38) (galope), mira a la derecha
     tintero.png 8x10 · libro.png 20x14 · bonos.png 3 filas (verde, violeta, naranja) x 2 cuadros de 10x6
     mecha.png       la máquina de obra pública: cuadros de 96x72, mira a la derecha
                     fila 0 quieto (2) · fila 1 avanzar (4) · fila 2 pala (4) · fila 3 dañada (1) + rota (1)
"""
import colorsys
import os

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.join(AQUI, "..", "sprites")
ENE = os.path.join(SPR, "enemigos")
JEF = os.path.join(SPR, "jefes")
OSCURO = (26, 16, 24)


# ------------------------------------------------------------------ repintes
def hls(c):
    return colorsys.rgb_to_hls(c[0] / 255, c[1] / 255, c[2] / 255)


def rgb(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return int(r * 255), int(g * 255), int(b * 255)


def repintar(origen, destino, regla):
    """regla(r, g, b, y_en_cuadro) -> (r, g, b) o None (= sin cambios)."""
    im = Image.open(origen).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        yc = y % 48
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            nuevo = regla(r, g, b, yc)
            if nuevo:
                px[x, y] = nuevo + (a,)
    im.save(destino)


def es_azul(h, l, s):
    return 0.53 < h < 0.75 and s > 0.12 and l > 0.1


def regla_paz(r, g, b, y):
    h, l, s = hls((r, g, b))
    if 0.45 < h < 0.56 and s > 0.15:                 # saco verde azulado -> azul de general
        return rgb(0.62, l * 0.9, 0.55)
    if (h > 0.95 or h < 0.02) and s > 0.4:           # pantalón rojo -> blanco
        return rgb(0.11, 0.48 + l * 0.75, 0.12)
    if y < 20 and l < 0.16 and (r, g, b) not in ((16, 9, 14), (13, 6, 11), (15, 8, 13)):  # melena -> castaño
        return rgb(0.07, 0.1 + l * 1.6, 0.42)
    return None


def regla_rivadavia(r, g, b, y):
    h, l, s = hls((r, g, b))
    if es_azul(h, l, s):
        if y >= 27:                                  # pantalón -> beige claro
            return rgb(0.1, 0.42 + l * 0.6, 0.22)
        return rgb(0.75, l * 0.42, 0.12)             # levita negra
    if y < 15 and s > 0.25 and l > 0.15:             # pompón rojo del chacó -> negro (galera)
        return rgb(0.75, 0.1, 0.1)
    return None


def regla_rosas(r, g, b, y):
    h, l, s = hls((r, g, b))
    if es_azul(h, l, s):
        if y >= 27:                                  # pantalón punzó
            return rgb(0.99, l * 1.15, 0.62)
        return rgb(0.63, l * 0.85, 0.45)             # saco azul
    if y < 15 and l > 0.09 and l < 0.3:              # sombrero -> rojo punzó oscuro
        return rgb(0.99, l * 1.2, 0.55)
    return None


def regla_tesorero(r, g, b, y):
    h, l, s = hls((r, g, b))
    if 0.08 < h < 0.19 and s > 0.55 and l > 0.55:      # fogonazo del fusil -> fajo de billetes verde
        return (150, 206, 120)
    if (h > 0.93 or h < 0.04) and s > 0.25 and l > 0.15:   # casaca roja -> levita negra violácea
        return rgb(0.78, l * 0.45, 0.22)
    if l > 0.6 and s < 0.25:                         # pantalón blanco -> gris
        return rgb(0.6, l * 0.62, 0.06)
    return None


# ------------------------------------------------------------------ lienzo para dibujar
class Lienzo:
    def __init__(self, w, h):
        self.a = np.zeros((h, w, 4), np.uint8)
        self.w, self.h = w, h
        self.oy = 0  # corre todo el dibujo hacia abajo (para que no se corte arriba)

    def p(self, x, y, c):
        x, y = int(round(x)), int(round(y)) + self.oy
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = tuple(c[:3]) + (255,)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.p(x, y, c)

    def linea(self, x0, y0, x1, y1, c, grosor=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) or 1
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            y = y0 + (y1 - y0) * i / n
            for dx in range(grosor):
                for dy in range(grosor):
                    self.p(x + dx - grosor // 2, y + dy - grosor // 2, c)

    def elipse(self, cx, cy, rx, ry, c, luz=None, sombra=None):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    col = c
                    if sombra and dy > 0.35:
                        col = sombra
                    elif luz and dy < -0.45 and dx < 0.3:
                        col = luz
                    self.p(x, y, col)

    def poligono(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            for i in range(len(pts)):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
                if (y0 <= y < y1) or (y1 <= y < y0):
                    xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for k in range(0, len(xs) - 1, 2):
                for x in range(int(round(xs[k])), int(round(xs[k + 1])) + 1):
                    self.p(x, y, c)

    def contorno(self, c=OSCURO):
        op = self.a[:, :, 3] > 0
        borde = np.zeros_like(op)
        borde[1:, :] |= op[:-1, :]
        borde[:-1, :] |= op[1:, :]
        borde[:, 1:] |= op[:, :-1]
        borde[:, :-1] |= op[:, 1:]
        borde &= ~op
        self.a[borde] = tuple(c) + (255,)

    def imagen(self):
        return Image.fromarray(self.a, "RGBA")


# ------------------------------------------------------------------ caballería
CABALLO = (122, 74, 42)
CABALLO_L = (158, 104, 62)
CABALLO_S = (84, 48, 28)
CRIN = (40, 26, 22)
SACO = (70, 104, 160)
SACO_S = (48, 70, 116)
BLANCO = (226, 222, 210)
PIEL = (214, 160, 120)
METAL = (210, 214, 222)


def jinete(k):
    c = Lienzo(48, 40)
    c.oy = 4
    sube = (0, -1, 0, 1)[k]
    # patas: (cadera, rodilla, casco) para las 4 fases del galope
    poses = [
        [((31, 23), (37, 28), (41, 31)), ((28, 23), (31, 29), (35, 33)), ((15, 23), (11, 28), (6, 30)), ((18, 23), (16, 29), (13, 33))],
        [((31, 23), (33, 29), (33, 34)), ((28, 23), (27, 29), (25, 34)), ((15, 23), (15, 29), (17, 34)), ((18, 23), (20, 29), (22, 33))],
        [((31, 23), (28, 28), (25, 31)), ((28, 23), (24, 27), (21, 30)), ((15, 23), (19, 28), (22, 32)), ((18, 23), (22, 28), (26, 31))],
        [((31, 23), (35, 27), (38, 30)), ((28, 23), (30, 28), (30, 33)), ((15, 23), (12, 29), (10, 34)), ((18, 23), (19, 29), (19, 34))],
    ][k]
    for i, (a, b, d) in enumerate(poses):
        col = CABALLO_S if i % 2 else CABALLO
        c.linea(a[0], a[1] + sube, b[0], b[1], col, 2)
        c.linea(b[0], b[1], d[0], d[1], col, 2)
        c.p(d[0], d[1], CRIN)
        c.p(d[0] + 1, d[1], CRIN)
    # cuerpo, cola, cuello y cabeza
    c.elipse(23, 19 + sube, 12, 6, CABALLO, CABALLO_L, CABALLO_S)
    c.linea(11, 16 + sube, 6, 22 + sube + (k % 2), CRIN, 2)
    c.poligono([(30, 14 + sube), (36, 7 + sube), (40, 9 + sube), (35, 19 + sube)], CABALLO)
    c.rect(38, 6 + sube, 44, 10 + sube, CABALLO)
    c.rect(43, 9 + sube, 45, 11 + sube, CABALLO_S)
    c.p(40, 7 + sube, CRIN)
    c.linea(31, 13 + sube, 37, 6 + sube, CRIN, 2)          # crin
    c.p(37, 4 + sube, CABALLO_S)                            # oreja
    # montura, pierna y jinete
    c.rect(19, 12 + sube, 27, 14 + sube, (90, 40, 34))
    c.rect(22, 14 + sube, 25, 19 + sube, BLANCO)
    c.rect(22, 19 + sube, 25, 21 + sube, CRIN)
    c.rect(20, 3 + sube, 27, 12 + sube, SACO)
    c.rect(20, 9 + sube, 27, 12 + sube, SACO_S)
    c.rect(26, 4 + sube, 27, 9 + sube, (220, 186, 80))     # charretera / correaje
    c.rect(22, 0 + sube, 26, 3 + sube, PIEL)
    c.rect(21, -3 + sube, 26, 0 + sube, CRIN)               # morrión
    c.linea(27, 6 + sube, 37, -1 + sube + (k % 2), METAL)   # sable en alto
    c.contorno()
    return c.imagen()


# ------------------------------------------------------------------ objetos
def tintero():
    c = Lienzo(8, 10)
    c.rect(1, 3, 6, 9, (44, 56, 98))
    c.rect(1, 6, 6, 9, (20, 22, 40))
    c.rect(2, 1, 5, 2, (128, 84, 50))
    c.p(2, 4, (190, 210, 240))
    c.p(2, 5, (150, 170, 210))
    c.contorno()
    return c.imagen()


def libro():
    c = Lienzo(20, 14)
    c.poligono([(1, 4), (15, 1), (18, 4), (4, 8)], (128, 44, 34))
    c.poligono([(4, 8), (18, 4), (18, 9), (4, 13)], (232, 222, 192))
    for k in range(3):
        c.linea(5, 10 + k, 17, 6 + k, (196, 184, 150))
    c.poligono([(1, 4), (4, 8), (4, 13), (1, 9)], (96, 30, 24))
    c.linea(6, 4, 13, 2, (226, 182, 80))
    c.linea(7, 6, 14, 4, (226, 182, 80))
    c.contorno()
    return c.imagen()


def bonos():
    hoja = Image.new("RGBA", (20, 18))
    tonos = [((128, 188, 112), (66, 118, 62)), ((178, 140, 210), (104, 72, 140)), ((230, 158, 92), (150, 88, 44))]
    for fila, (claro, oscuro) in enumerate(tonos):
        a = Lienzo(10, 6)
        a.rect(1, 1, 8, 4, claro)
        a.rect(4, 2, 5, 3, oscuro)          # el "retrato" del medio (genérico)
        a.p(2, 2, oscuro)
        a.p(7, 3, oscuro)
        a.contorno(oscuro)
        b = Lienzo(10, 6)                   # de canto (cuando gira en el aire)
        b.rect(2, 2, 7, 3, claro)
        b.contorno(oscuro)
        hoja.alpha_composite(a.imagen(), (0, fila * 6))
        hoja.alpha_composite(b.imagen(), (10, fila * 6))
    return hoja


# ------------------------------------------------------------------ la máquina de obra pública
AMA = (226, 166, 40)
AMA_L = (250, 208, 92)
AMA_S = (170, 112, 24)
GRIS = (104, 106, 116)
GRIS_L = (156, 158, 166)
GRIS_S = (64, 64, 74)
ORUGA = (50, 48, 56)
VIDRIO = (70, 104, 124)
FANT = (176, 226, 186)

LETRAS = {  # fuente 3x5 para el cartel
    "O": ["111", "101", "101", "101", "111"], "B": ["110", "101", "110", "101", "110"],
    "R": ["110", "101", "110", "101", "101"], "A": ["010", "101", "111", "101", "101"],
}


def cartel(c, x, y, texto):
    c.rect(x - 1, y - 1, x + len(texto) * 4 - 1, y + 5, (236, 232, 220))
    for i, ch in enumerate(texto):
        for fy, fila in enumerate(LETRAS[ch]):
            for fx, v in enumerate(fila):
                if v == "1":
                    c.p(x + i * 4 + fx, y + fy, (30, 30, 36))


def mecha(fase, k):
    """fase: quieto / avanzar / pala / dañada / rota."""
    c = Lienzo(96, 72)
    rota = fase == "rota"
    bob = (k % 2) if fase == "quieto" else 0
    oy = bob + (3 if rota else 0)
    # orugas
    c.rect(16, 56, 74, 68, ORUGA)
    c.elipse(16, 62, 5, 6, ORUGA)
    c.elipse(74, 62, 5, 6, ORUGA)
    paso = (k * 3) % 6 if fase == "avanzar" else 0
    for x in range(12 + paso, 79, 6):
        c.rect(x, 56, x + 1, 56, GRIS_L)
        c.rect(x, 68, x + 1, 68, GRIS)
    for x in (22, 34, 46, 58, 70):
        c.elipse(x, 62, 4, 4, GRIS, GRIS_L, GRIS_S)
        c.p(x, 62, (196, 198, 204))
    # motores (atrás = izquierda): el punto débil, con rejillas que brillan
    for i, y in enumerate((30, 42)):
        c.rect(3, y + oy, 20, y + 9 + oy, GRIS)
        c.rect(3, y + oy, 20, y + 2 + oy, GRIS_L)
        c.rect(3, y + 7 + oy, 20, y + 9 + oy, GRIS_S)
        brillo = (255, 140, 40) if not rota else (90, 60, 50)
        for x in range(6, 18, 3):
            c.rect(x, y + 4 + oy, x + 1, y + 5 + oy, brillo)
    c.rect(8, 12 + oy, 11, 30 + oy, GRIS_S)              # caño de escape
    c.rect(7, 11 + oy, 12, 13 + oy, GRIS)
    # chasis amarillo con franja de peligro
    c.rect(18, 34 + oy, 70, 55, AMA)
    c.rect(18, 34 + oy, 70, 36 + oy, AMA_L)
    c.rect(18, 50, 70, 55, AMA_S)
    for x in range(18, 71):
        for y in range(50, 55):
            if ((x + y) // 3) % 2 == 0:
                c.p(x, y, (34, 30, 34))
    # cartel de peligro (simétrico: se lee igual cuando la máquina mira al otro lado)
    c.poligono([(30, 38 + oy), (37, 48 + oy), (23, 48 + oy)], (196, 44, 36))
    c.poligono([(30, 41 + oy), (34, 47 + oy), (26, 47 + oy)], (240, 236, 224))
    c.rect(30, 42 + oy, 30, 44 + oy, (30, 30, 36))
    c.p(30, 46 + oy, (30, 30, 36))
    # cabina con el villano fantasma adentro
    c.rect(40, 14 + oy, 63, 35 + oy, AMA)
    c.rect(40, 14 + oy, 63, 15 + oy, AMA_L)
    c.rect(43, 17 + oy, 60, 30 + oy, VIDRIO)
    if not rota:
        # el jefe final en la cabina: pelo oscuro, bigote, camisa celeste y saco azul
        c.rect(46, 26 + oy, 56, 30 + oy, (52, 62, 124))   # saco
        c.rect(50, 26 + oy, 52, 30 + oy, (196, 226, 228))  # camisa
        c.rect(48, 19 + oy, 54, 26 + oy, (200, 148, 112))  # cara
        c.rect(48, 18 + oy, 54, 19 + oy, (40, 34, 36))     # pelo
        c.p(48, 20 + oy, (40, 34, 36))
        c.p(50, 22 + oy, (30, 24, 26))
        c.p(53, 22 + oy, (30, 24, 26))
        c.rect(50, 24 + oy, 53, 24 + oy, (44, 34, 34))     # bigote
    c.linea(44, 18 + oy, 47, 29 + oy, (150, 190, 210))   # reflejo del vidrio
    # brazo y pala (adelante = derecha)
    if fase == "pala":
        codo, punta = [((80, 18), (88, 6)), ((78, 14), (84, 2)), ((84, 30), (92, 54)), ((82, 26), (90, 46))][k]
    elif rota:
        codo, punta = (78, 44), (88, 64)
    else:
        codo, punta = (80, 24 + bob), (86, 44 + bob)
    c.linea(64, 38 + oy, codo[0], codo[1] + oy, AMA_S, 4)
    c.linea(64, 37 + oy, codo[0], codo[1] - 1 + oy, AMA, 2)
    c.linea(codo[0], codo[1] + oy, punta[0], punta[1] + oy, AMA_S, 3)
    c.linea(codo[0], codo[1] - 1 + oy, punta[0] - 1, punta[1] + oy, AMA, 1)
    bx, by = punta[0], punta[1] + oy
    c.poligono([(bx - 6, by - 3), (bx + 6, by - 5), (bx + 8, by + 7), (bx - 4, by + 6)], GRIS)
    c.poligono([(bx - 6, by - 3), (bx + 6, by - 5), (bx + 6, by - 2), (bx - 5, by)], GRIS_L)
    for d in range(4):                                    # dientes
        c.p(bx - 3 + d * 3, by + 7, METAL)
        c.p(bx - 3 + d * 3, by + 8, METAL)
    if fase == "dañada":
        for x, y in ((30, 38), (52, 30), (12, 34)):
            c.rect(x, y, x + 2, y + 1, (40, 30, 30))
    if rota:
        for x, y in ((24, 36), (36, 44), (56, 20), (10, 32), (62, 40)):
            c.rect(x, y + oy, x + 3, y + 2 + oy, (36, 30, 32))
    c.contorno()
    return c.imagen()


def generar():
    os.makedirs(JEF, exist_ok=True)
    repintar(os.path.join(SPR, "quiroga_16px.png"), os.path.join(ENE, "paz_16px.png"), regla_paz)
    repintar(os.path.join(ENE, "artillero_16px.png"), os.path.join(ENE, "rivadavia_16px.png"), regla_rivadavia)
    repintar(os.path.join(ENE, "marinero_16px.png"), os.path.join(ENE, "rosas_16px.png"), regla_rosas)
    # el jefe final (tesorero_16px.png) ya no es un repinte: sale de gen_jefe_final.py (v7.2)

    hoja = Image.new("RGBA", (48 * 4, 40))
    for k in range(4):
        hoja.alpha_composite(jinete(k), (k * 48, 0))
    hoja.save(os.path.join(JEF, "caballeria.png"))
    tintero().save(os.path.join(JEF, "tintero.png"))
    libro().save(os.path.join(JEF, "libro.png"))
    bonos().save(os.path.join(JEF, "bonos.png"))

    hoja = Image.new("RGBA", (96 * 4, 72 * 4))
    filas = [[("quieto", 0), ("quieto", 1)], [("avanzar", k) for k in range(4)],
             [("pala", k) for k in range(4)], [("dañada", 0), ("rota", 0)]]
    for f, cuadros in enumerate(filas):
        for k, (fase, n) in enumerate(cuadros):
            hoja.alpha_composite(mecha(fase, n), (k * 96, f * 72))
    hoja.save(os.path.join(JEF, "mecha.png"))
    print("listo")


if __name__ == "__main__":
    generar()
