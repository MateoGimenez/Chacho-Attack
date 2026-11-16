"""Arma la hoja del jefe CORONEL cambiando la paleta del artillero (técnica clásica de beat 'em up).

Uso (desde fuentes/):  python3 gen_coronel.py
  - el azul del uniforme pasa a bordó
  - lo blanco/crema (correaje, pantalón) pasa a dorado
Si el artista dibuja un Coronel propio, reemplacen sprites/enemigos/coronel_16px.png (misma grilla 8x6 de 64x48).
"""
import colorsys
import os

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ENEM = os.path.join(AQUI, "..", "sprites", "enemigos")


def cambiar(col):
    r, g, b, a = col
    if a == 0:
        return col
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    hd = h * 360
    if 185 <= hd <= 265 and s > 0.18:          # azul del uniforme -> bordó
        h, s, v = 350 / 360, min(1.0, s * 1.25 + 0.1), min(1.0, v * 1.05)
    elif s < 0.22 and v > 0.62:                 # blanco / crema -> dorado
        h, s, v = 44 / 360, 0.55, min(1.0, v * 0.98)
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (round(r * 255), round(g * 255), round(b * 255), a)


if __name__ == "__main__":
    im = Image.open(os.path.join(ENEM, "artillero_16px.png")).convert("RGBA")
    im.putdata([cambiar(p) for p in im.getdata()])
    im.save(os.path.join(ENEM, "coronel_16px.png"))
    print("coronel", im.size)
