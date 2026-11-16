"""Prepara a Facundo Quiroga para el fondo del menú.

1) src/quiroga_retrato.png: el retrato (recortado de la propuesta del equipo).
2) rembg (modelo isnet-general-use) le saca el fondo -> src/quiroga_cut.png
3) filtro de "ilustración" para que combine con el Chacho y el señor de traje:
   más contraste y color, suavizado bilateral, 20 colores (k-means) y líneas oscuras -> src/quiroga_comic.png
Uso: python3 preparar_quiroga.py   (necesita rembg, opencv-python, numpy, Pillow)
"""
import cv2
import numpy as np
from PIL import Image, ImageEnhance

try:
    from rembg import new_session, remove
    im = Image.open("src/quiroga_retrato.png").convert("RGB")
    big = im.resize((im.width * 3, im.height * 3), Image.LANCZOS)
    cut = remove(big, session=new_session("isnet-general-use")).convert("RGBA")
    a = np.array(cut)
    a[..., 3] = np.where(a[..., 3] > 150, 255, 0)
    cut = Image.fromarray(a, "RGBA")
    cut = cut.crop(cut.getbbox())
    cut.save("src/quiroga_cut.png")
except ImportError:
    cut = Image.open("src/quiroga_cut.png").convert("RGBA")

al = np.array(cut.split()[-1])
n, lbl, st, _ = cv2.connectedComponentsWithStats((al > 0).astype(np.uint8), 8)
grande = 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
al = np.where(lbl == grande, 255, 0).astype(np.uint8)
rgb = cut.convert("RGB")
rgb = ImageEnhance.Contrast(rgb).enhance(1.25)
rgb = ImageEnhance.Brightness(rgb).enhance(1.12)
rgb = ImageEnhance.Color(rgb).enhance(1.25)
a = np.array(rgb)
for _ in range(3):
    a = cv2.bilateralFilter(a, 9, 30, 9)
Z = a.reshape(-1, 3).astype(np.float32)
crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 1.0)
cv2.setRNGSeed(7)
_, lab, cen = cv2.kmeans(Z, 20, None, crit, 3, cv2.KMEANS_PP_CENTERS)
a = cen[lab.flatten()].reshape(a.shape).astype(np.uint8)
gray = cv2.medianBlur(cv2.cvtColor(np.array(rgb), cv2.COLOR_RGB2GRAY), 5)
bordes = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 9, 5)
a = (a.astype(np.float32) * (0.5 + 0.5 * (bordes[..., None] / 255))).astype(np.uint8)
out = Image.fromarray(a).convert("RGBA")
out.putalpha(Image.fromarray(al))
out.crop(out.getbbox()).save("src/quiroga_comic.png")
print("quiroga_comic listo")
