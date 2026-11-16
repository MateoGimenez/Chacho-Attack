"""Genera el fondo, el logo y el cursor del menú de Chacho Attack.

Uso:  python3 gen_menu.py
Necesita: Pillow, numpy, opencv-python. Lee las imágenes de src/ y escribe en export/.
Los personajes ya recortados están en src/*_cut.png (recorte hecho con rembg).
v4: se suma FACUNDO QUIROGA (src/quiroga_comic.png, recortado del retrato con rembg y pasado
por un filtro de ilustración con preparar_quiroga.py), el segundo
personaje jugable: a todo color y con contorno de sticker, entre el Chacho y el señor de traje.
"""
import math
import os
import random

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

random.seed(7)
np.random.seed(7)
W, H = 1920, 1080
SRC, OUT = "src", "export"
os.makedirs(OUT, exist_ok=True)
FUENTE_LOGO = f"{SRC}/SedgwickAveDisplay-Regular.ttf"
FUENTE_PIXEL = f"{SRC}/PressStart2P-Regular.ttf"


# ---------------------------------------------------------------- utilidades
def a_np(im):
    return np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0


def a_img(arr):
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")


def disco(r):
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))


def contorno(rgba, capas):
    """Agrega contornos tipo sticker. capas = [(radio, (r,g,b)), ...] de adentro hacia afuera."""
    a = np.asarray(rgba.split()[-1])
    pad = sum(r for r, _ in capas) + 4
    lienzo = Image.new("RGBA", (rgba.width + 2 * pad, rgba.height + 2 * pad), (0, 0, 0, 0))
    a = np.pad(a, pad)
    total = 0
    radios = []
    for r, col in capas:
        total += r
        radios.append((total, col))
    for r, col in reversed(radios):
        m = cv2.dilate((a > 110).astype(np.uint8) * 255, disco(r))
        m = cv2.GaussianBlur(m, (3, 3), 0)
        capa = Image.new("RGBA", lienzo.size, col + (255,))
        capa.putalpha(Image.fromarray(m))
        lienzo.alpha_composite(capa)
    lienzo.alpha_composite(rgba, (pad, pad))
    return lienzo


def tintar(rgba, oscuro, claro, cantidad=1.0):
    """Duotono: mapea la luminancia entre dos colores (como el personaje rojizo de la referencia)."""
    arr = a_np(rgba)
    lum = arr[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)
    lum = np.clip((lum - 0.08) / 0.85, 0, 1) ** 0.9
    o, c = np.array(oscuro, np.float32) / 255, np.array(claro, np.float32) / 255
    duo = o + (c - o) * lum[..., None]
    arr[..., :3] = arr[..., :3] * (1 - cantidad) + duo * cantidad
    return a_img(arr)


def escalar_alto(im, alto):
    return im.resize((round(im.width * alto / im.height), alto), Image.LANCZOS)


def estrella(d, cx, cy, r, col, ancho=0.18):
    """Brillo de 4 puntas."""
    pts = []
    for k in range(8):
        ang = math.pi / 4 * k - math.pi / 2
        rr = r if k % 2 == 0 else r * ancho
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.polygon(pts, fill=col)


# ---------------------------------------------------------------- fondo
def fondo():
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = np.clip((xx / W) * 0.95 + (yy / H) * -0.2 + 0.08, 0, 1)
    stops = [(0.0, (52, 84, 160)), (0.38, (128, 132, 200)), (0.55, (214, 176, 214)),
             (0.72, (240, 146, 146)), (1.0, (212, 56, 68))]
    col = np.zeros((H, W, 3), np.float32)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        k = np.clip((t - t0) / (t1 - t0), 0, 1)[..., None]
        seg = np.array(c0, np.float32) / 255 + (np.array(c1, np.float32) - np.array(c0, np.float32)) / 255 * k
        dentro = ((t >= t0) & (t <= t1))[..., None]
        col = np.where(dentro, seg, col)
    rosa = np.array([246, 170, 170]) / 255
    g = np.exp(-(((xx - 1500) / 520) ** 2 + ((yy - 120) / 380) ** 2))[..., None]
    col = col + (rosa - col) * g * 0.55
    dx, dy = 0.46, 1.0
    n = math.hypot(dx, dy)
    dist = ((xx - 1180) * dy - (yy - 0) * dx) / n
    haz = np.exp(-(dist / 120) ** 2) * 0.85 + np.exp(-(dist / 300) ** 2) * 0.35
    col = col + (1 - col) * haz[..., None]
    grano = np.random.normal(0, 0.035, (H // 2, W // 2)).astype(np.float32)
    grano = cv2.resize(grano, (W, H), interpolation=cv2.INTER_NEAREST)
    col = col + grano[..., None]
    arr = np.dstack([np.clip(col, 0, 1), np.ones((H, W))]).astype(np.float32)
    im = a_img(arr)

    capa = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    pts = [(0, H)]
    x = 0
    y = 860
    while x < 1100:
        x += random.randint(40, 90)
        y = max(700, min(930, y + random.randint(-70, 60)))
        pts.append((x, y))
    pts += [(1100, H)]
    d.polygon(pts, fill=(40, 60, 110, 110))
    for (cx, cy, rad, col_t) in [(140, 980, 520, (30, 50, 120)), (1880, 60, 460, (160, 30, 50))]:
        for py in range(cy - rad, cy + rad, 22):
            for px in range(cx - rad, cx + rad, 22):
                dd = math.hypot(px - cx, py - cy) / rad
                if dd < 1:
                    r = (1 - dd) * 7
                    if r > 0.8:
                        d.ellipse((px - r, py - r, px + r, py + r), fill=col_t + (150,))
    for cx, cy, r in [(380, 70, 46), (520, 160, 30), (240, 300, 38), (900, 60, 28), (1300, 980, 36)]:
        for k in range(0, 360, 14):
            a0, a1 = math.radians(k), math.radians(k + 8)
            d.line([(cx + r * math.cos(a0), cy + r * math.sin(a0)),
                    (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(255, 255, 255, 200), width=4)
        d.ellipse((cx - r + 6, cy - r + 6, cx + r - 6, cy + r - 6), fill=(255, 255, 255, 40))
    im.alpha_composite(capa)
    return im


def explosion_comic(r_ext, r_int, puntas=14):
    """Estallido amarillo con puntos, como el de la hamburguesa de la referencia."""
    s = r_ext * 2 + 20
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = s / 2
    pts = []
    for k in range(puntas * 2):
        ang = math.pi * k / puntas + 0.2
        rr = (r_ext if k % 2 == 0 else r_int) * random.uniform(0.85, 1.05)
        pts.append((c + rr * math.cos(ang), c + rr * math.sin(ang)))
    d.polygon(pts, fill=(255, 214, 60, 255))
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    dots = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dots)
    for py in range(0, s, 14):
        for px in range(0, s, 14):
            dd.ellipse((px, py, px + 6, py + 6), fill=(255, 250, 230, 255))
    im.paste(dots, (0, 0), Image.composite(dots.split()[-1], Image.new("L", (s, s), 0), mask))
    for k in range(len(pts)):
        a, b = pts[k], pts[(k + 1) % len(pts)]
        d.line([a, b], fill=(255, 255, 255, 255), width=6)
    return im


def item(sheet, col, fila, escala):
    spr = sheet.crop((col * 32, fila * 32, col * 32 + 32, fila * 32 + 32))
    spr = spr.crop(spr.getbbox())
    spr = contorno(spr, [(1, (34, 52, 120))]).crop()
    spr = spr.crop(spr.getbbox())
    spr = spr.resize((spr.width * escala, spr.height * escala), Image.NEAREST)
    return contorno(spr, [(5, (255, 255, 255))])


def brillos(im, n, zona, tam):
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = zona
    for _ in range(n):
        cx, cy = random.randint(x0, x1), random.randint(y0, y1)
        r = random.randint(*tam)
        estrella(d, cx, cy, r * 1.25, (255, 255, 255, 90))
        estrella(d, cx, cy, r, (255, 255, 255, 255))


# ---------------------------------------------------------------- logo
def texto_mascara(txt, fuente, tam):
    f = ImageFont.truetype(fuente, tam)
    l, t, r, b = f.getbbox(txt)
    m = Image.new("L", (r - l + 40, b - t + 40), 0)
    ImageDraw.Draw(m).text((20 - l, 20 - t), txt, font=f, fill=255)
    return m


def pincel(mask, base, oscuro, claro, angulo=-18):
    """Relleno con trazos de pincel: vetas oscuras y claras en diagonal."""
    w, h = mask.size
    ruido = np.random.rand(h // 6 + 2, w // 60 + 2).astype(np.float32)
    ruido = cv2.resize(ruido, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC)
    M = cv2.getRotationMatrix2D((w, h), angulo, 1)
    ruido = cv2.warpAffine(ruido, M, (w * 2, h * 2))[h // 2:h // 2 + h, w // 2:w // 2 + w]
    b, o, c = (np.array(x, np.float32) / 255 for x in (base, oscuro, claro))
    col = np.zeros((h, w, 3), np.float32) + b
    col = np.where((ruido < 0.3)[..., None], o, col)
    col = np.where((ruido > 0.82)[..., None], c, col)
    ray = np.zeros((h, w), np.uint8)
    for _ in range(int(w * h / 9000)):
        x, y = random.randint(0, w), random.randint(0, h)
        L = random.randint(10, 40)
        cv2.line(ray, (x, y), (x + L, y - int(L * 0.35)), 255, 2)
    col = np.where((ray > 0)[..., None], np.array([1, 0.95, 0.92], np.float32), col)
    a = np.asarray(mask).astype(np.float32) / 255
    return a_img(np.dstack([col, a]))


def borde_rugoso(mask, fuerza=3):
    a = np.asarray(mask).astype(np.float32)
    ruido = cv2.resize(np.random.rand(a.shape[0] // 4 + 1, a.shape[1] // 4 + 1).astype(np.float32),
                       (a.shape[1], a.shape[0]))
    a = cv2.GaussianBlur(a, (0, 0), fuerza)
    a = ((a / 255 + (ruido - 0.5) * 0.35) > 0.5).astype(np.uint8) * 255
    return Image.fromarray(a)


def logo():
    m1 = borde_rugoso(texto_mascara("CHACHO", FUENTE_LOGO, 190), 2.5)
    m2 = borde_rugoso(texto_mascara("ATTACK", FUENTE_LOGO, 260), 3)
    chacho = pincel(m1, (24, 22, 26), (8, 8, 10), (90, 86, 92))
    attack = pincel(m2, (214, 32, 38), (138, 10, 22), (246, 92, 76))
    chacho = contorno(chacho, [(10, (255, 255, 255)), (6, (12, 10, 14))])
    attack = contorno(attack, [(12, (255, 255, 255)), (7, (12, 10, 14))])
    lw = max(chacho.width + 120, attack.width) + 40
    lienzo = Image.new("RGBA", (lw, chacho.height + attack.height - 70), (0, 0, 0, 0))
    lienzo.alpha_composite(attack, (0, chacho.height - 90))
    lienzo.alpha_composite(chacho, (lw - chacho.width - 40, 0))
    sombra = Image.new("RGBA", lienzo.size, (20, 10, 30, 0))
    sombra.putalpha(lienzo.split()[-1].point(lambda v: v * 0.45).filter(ImageFilter.GaussianBlur(10)))
    final = Image.new("RGBA", (lienzo.width + 40, lienzo.height + 40), (0, 0, 0, 0))
    final.alpha_composite(sombra, (28, 30))
    final.alpha_composite(lienzo, (14, 10))
    final = final.rotate(6, resample=Image.BICUBIC, expand=True)
    return final.crop(final.getbbox())


# ---------------------------------------------------------------- composición
def quiroga():
    """Facundo Quiroga recortado del retrato: a todo color (algo más saturado) y con contorno
    de sticker blanco + azul verdoso (el color de su saco), igual que el Chacho."""
    q = Image.open(f"{SRC}/quiroga_comic.png")   # ver preparar_quiroga.py (filtro de ilustración)
    q = escalar_alto(q, 860)
    return contorno(q, [(8, (255, 255, 255)), (5, (24, 62, 70))])


def componer():
    im = fondo()
    sheet = Image.open(f"{SRC}/items.png").convert("RGBA")

    # 1) jinete (fondo, derecha) en duotono rojizo
    caballo = Image.open(f"{SRC}/caballo_cut.png")
    caballo = escalar_alto(caballo, 1500)
    caballo = tintar(caballo, (120, 20, 40), (255, 190, 175), 0.92)
    caballo.putalpha(caballo.split()[-1].point(lambda v: int(v * 0.9)))
    im.alpha_composite(caballo, (W - caballo.width + 170, -60))

    brillos(im, 14, (80, 20, 1850, 600), (10, 28))
    for (c, f, esc, x, y, rot) in [(1, 1, 5, 1170, 40, -12), (3, 3, 5, 870, 6, 12),
                                   (2, 2, 4, 50, 30, -10), (0, 1, 4, 1760, 470, -8)]:
        spr = item(sheet, c, f, esc).rotate(rot, expand=True, resample=Image.NEAREST)
        im.alpha_composite(spr, (x, y))

    # 2) señor del traje (centro-atrás), lavado con luz fría
    traje = Image.open(f"{SRC}/traje_cut.png")
    traje = escalar_alto(traje, 860)
    arr = a_np(traje)
    frio = np.array([200, 228, 255], np.float32) / 255
    arr[..., :3] = arr[..., :3] * 0.66 + frio * 0.34
    traje = a_img(arr)
    im.alpha_composite(traje, (1230, 40))

    # 3) Facundo Quiroga: segundo protagonista, entre el traje y el Chacho
    q = quiroga()
    im.alpha_composite(q, (1275, H - q.height + 40))

    # 4) Chacho: el protagonista, adelante, a todo color y con contorno de sticker
    chacho = Image.open(f"{SRC}/chacho_cut.png")
    chacho = escalar_alto(chacho, 940)
    arr = a_np(chacho)
    lum = arr[..., :3].mean(axis=2, keepdims=True)
    arr[..., :3] = np.clip(lum + (arr[..., :3] - lum) * 1.25, 0, 1)
    chacho = contorno(a_img(arr), [(9, (255, 255, 255)), (5, (150, 18, 30))])
    cx = 720
    im.alpha_composite(chacho, (cx, H - chacho.height + 30))

    # estallido + choripán abajo a la derecha (más chico y más en la esquina: no tapa a Quiroga)
    boom = explosion_comic(175, 115)
    bx, by = 1600, 760
    im.alpha_composite(boom, (bx, by))
    chori = item(sheet, 0, 0, 7).rotate(-14, expand=True, resample=Image.NEAREST)
    im.alpha_composite(chori, (bx + boom.width // 2 - chori.width // 2,
                               by + boom.height // 2 - chori.height // 2))
    brillos(im, 8, (60, 300, 1900, 1040), (8, 22))
    return im.convert("RGB").convert("RGBA")


def pixelar(im, ancho, alto, colores=160):
    chico = im.resize((ancho, alto), Image.LANCZOS)
    rgb = chico.convert("RGB").quantize(colores, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    return rgb.convert("RGBA")


def pixelar_alpha(im, ancho, colores=40):
    alto = round(im.height * ancho / im.width)
    chico = im.resize((ancho, alto), Image.LANCZOS)
    a = chico.split()[-1].point(lambda v: 255 if v > 120 else 0)
    rgb = chico.convert("RGB").quantize(colores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def cursor():
    sheet = Image.open(f"{SRC}/items.png").convert("RGBA")
    spr = sheet.crop((0, 0, 32, 32))
    spr = spr.crop(spr.getbbox())
    spr = contorno(spr, [(1, (20, 14, 22))])
    return spr.crop(spr.getbbox())


if __name__ == "__main__":
    fondo_hd = componer()
    fondo_hd.convert("RGB").save(f"{OUT}/fondo_menu_hd.png")
    lg = logo()
    lg.save(f"{OUT}/logo_hd.png")

    fondo_px = pixelar(fondo_hd, 480, 270)
    fondo_px.convert("RGB").save(f"{OUT}/fondo_menu.png")
    lg_px = pixelar_alpha(lg, 236)
    lg_px.save(f"{OUT}/logo.png")
    cursor().save(f"{OUT}/cursor_choripan.png")

    portada = fondo_hd.copy()
    lgs = lg.resize((int(lg.width * 0.92), int(lg.height * 0.92)), Image.LANCZOS)
    portada.alpha_composite(lgs, (40, 40))
    portada.convert("RGB").save(f"{OUT}/portada_hd.png")
    print("logo", lg.size, "logo px", lg_px.size)
