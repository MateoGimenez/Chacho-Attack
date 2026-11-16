"""Convierte pixel art a la grilla de 16px (mitad de resolucion).

Cada bloque de 2x2 pixeles se convierte en 1 pixel:
  - Si un color se repite en el bloque, gana el que mas se repite.
  - En empate, gana el color mas "raro" en la imagen (asi sobreviven
    los detalles finos: contornos, rejas, lineas de la calle, luces).
No se inventan colores nuevos: la paleta queda igual a la original.

Uso: python3 a_16px.py entrada.png salida.png
"""
import sys
from collections import Counter

import numpy as np
from PIL import Image


def a_16px(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    a = np.array(img)
    h, w = a.shape[:2]
    # completar a tamano par repitiendo el borde
    a = np.pad(a, ((0, h % 2), (0, w % 2), (0, 0)), mode="edge")
    h2, w2 = a.shape[0] // 2, a.shape[1] // 2

    # pixeles totalmente transparentes cuentan todos como el mismo color
    a[a[..., 3] == 0] = 0
    claves = (a.astype(np.uint32) * np.array([1 << 24, 1 << 16, 1 << 8, 1], dtype=np.uint32)).sum(-1)
    frecuencia = Counter(claves.ravel().tolist())

    out = np.zeros((h2, w2, 4), dtype=np.uint8)
    for y in range(h2):
        for x in range(w2):
            bloque = claves[2 * y:2 * y + 2, 2 * x:2 * x + 2].ravel().tolist()
            c = Counter(bloque)
            # mas repetido primero; en empate, el mas raro de la imagen
            mejor = max(c, key=lambda k: (c[k], -frecuencia[k]))
            iy, ix = divmod(bloque.index(mejor), 2)
            out[y, x] = a[2 * y + iy, 2 * x + ix]
    return Image.fromarray(out, "RGBA")


if __name__ == "__main__":
    entrada, salida = sys.argv[1], sys.argv[2]
    res = a_16px(Image.open(entrada))
    if Image.open(entrada).mode != "RGBA":
        res = res.convert("RGB")
    res.save(salida)
    print(salida, res.size)
