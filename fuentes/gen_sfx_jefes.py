"""Efectos de sonido de los jefes (v7). Mismo método que gen_sfx.py (sintetizados, sin derechos).

Uso (desde fuentes/):  python3 gen_sfx_jefes.py
Escribe en ../audio/sfx/ solo los sonidos nuevos (no toca los de gen_sfx.py).
"""
import numpy as np

from gen_sfx import (SR, barrido, cuadrada, envolvente, guardar, impacto, latigazo, mezclar, nota,
                     notas, pasa_altos, pasa_bajos, ruido, t, triangular)

rng = np.random.default_rng(23)


def silencio(seg):
    return np.zeros(int(SR * seg))


def generar():
    # --- Paz: silbido de dos notas (como llamando a la caballería) y esquive
    def pito(f0, f1, dur):
        fr = barrido(f0, f1, dur, 0.7) * (1 + 0.012 * np.sin(2 * np.pi * 7 * t(dur)))
        tono = triangular(fr) * envolvente(int(SR * dur), 0.02, 1.5)
        aire = pasa_altos(ruido(dur), 4000) * envolvente(int(SR * dur), 0.01, 3) * 0.12
        return tono + aire
    guardar("silbido", np.concatenate([pito(1800, 2300, 0.22), silencio(0.05), pito(2300, 1500, 0.45)]), 0.6)
    guardar("esquiva", latigazo(0.16, 6000, 1200), 0.45)

    # --- galope: golpes graves de a 3 (ta-ca-tán) repetidos, con retumbe de fondo
    dur = 2.4
    capas = [pasa_bajos(ruido(dur, 8), 300) * 0.25 * np.minimum(1, t(dur) * 4) * np.minimum(1, (dur - t(dur)) * 3)]
    pos = 0.0
    while pos < dur - 0.2:
        for k, d in enumerate((0.0, 0.07, 0.15)):
            casco = impacto(0.09, rng.uniform(90, 130), 40) * rng.uniform(0.4, 0.8)
            capas.append(np.concatenate([silencio(pos + d), casco]))
        pos += 0.3 + rng.uniform(-0.02, 0.02)
    guardar("galope", mezclar(*capas)[:int(SR * dur)], 0.85)

    # --- Rosas: tintero que se rompe, libro que cae, megáfono
    vidrio = [pasa_altos(ruido(0.05), 3000) * envolvente(int(SR * 0.05), 0, 60)]
    for k in range(6):
        f = rng.uniform(2500, 5200)
        d = 0.12
        tin = cuadrada(np.full(int(SR * d), f), 0.5) * envolvente(int(SR * d), 0, 30) * 0.15
        vidrio.append(np.concatenate([silencio(0.01 + 0.025 * k), tin]))
    salpica = pasa_bajos(ruido(0.25, 2), 1800) * envolvente(int(SR * 0.25), 0.005, 12) * 0.5
    guardar("tintero", mezclar(*vidrio, salpica), 0.7)
    guardar("libro", mezclar(impacto(0.3, 70, 10, crunch=0.5),
                             pasa_bajos(ruido(0.4, 4), 800) * envolvente(int(SR * 0.4), 0, 9) * 0.6), 0.9)
    dur = 0.7
    fr = barrido(220, 160, dur) * (1 + 0.25 * np.sign(np.sin(2 * np.pi * 9 * t(dur))))  # "uaa-uaa"
    voz = cuadrada(fr, 0.3) * envolvente(int(SR * dur), 0.02, 2.0)
    guardar("megafono", pasa_bajos(voz + pasa_bajos(ruido(dur, 3), 900) * 0.3, 2400), 0.7)
    guardar("aturdido", notas([(nota(n), 0.06) for n in (88, 84, 88, 84, 88)], duty=0.25, caida=8), 0.4)
    guardar("lanzar", latigazo(0.14, 3000, 900), 0.45)

    # --- jefe final: billetes, escudo, motor, pala, metal, explosión
    aleteo = [pasa_altos(ruido(0.03, 1), 2500) * envolvente(int(SR * 0.03), 0, 90) * rng.uniform(0.4, 0.9)
              for _ in range(8)]
    guardar("billetes", mezclar(*[np.concatenate([silencio(0.025 * k), a]) for k, a in enumerate(aleteo)]), 0.5)
    guardar("escudo", mezclar(notas([(nota(91), 0.05), (nota(96), 0.18)], duty=0.125, caida=10),
                              impacto(0.08, 400, 50) * 0.3), 0.45)
    dur = 1.3
    giro = barrido(45, 110, dur, 0.6) * (1 + 0.15 * np.sign(np.sin(2 * np.pi * 18 * t(dur))))
    motor = cuadrada(giro, 0.4) * envolvente(int(SR * dur), 0.05, 0.8)
    motor += pasa_bajos(ruido(dur, 4), barrido(300, 1500, dur)) * 0.5 * envolvente(int(SR * dur), 0.05, 1)
    guardar("motor", pasa_bajos(motor, 2000), 0.85)
    guardar("pala", mezclar(latigazo(0.3, 2500, 400, cuerpo=0.6), impacto(0.35, 60, 8) * 0.7), 0.9)
    clank = mezclar(*[cuadrada(np.full(int(SR * 0.25), f), 0.5) * envolvente(int(SR * 0.25), 0, 18) * 0.3
                      for f in (620, 935, 1410)], impacto(0.06, 300, 70) * 0.6)
    guardar("clank", clank, 0.55)
    dur = 1.1
    boom = mezclar(ruido(0.06) * envolvente(int(SR * 0.06), 0, 50),
                   pasa_bajos(ruido(dur, 5), barrido(2500, 150, dur, 0.4)) * envolvente(int(SR * dur), 0.003, 3.2) * 1.3,
                   cuadrada(barrido(70, 30, dur), 0.5) * envolvente(int(SR * dur), 0.0, 4) * 0.5)
    guardar("explosion", boom, 0.95)


if __name__ == "__main__":
    generar()
