"""Genera todos los efectos de sonido del juego (estilo 8-bit, sintetizados: sin derechos de autor).

Uso (desde fuentes/):  python3 gen_sfx.py
Necesita: numpy. Escribe WAV mono 16 bits a 22050 Hz en ../audio/sfx/

Cómo están hechos (receta clásica tipo sfxr / NES):
  - onda cuadrada o triangular con barrido de frecuencia (tonos, jingles, "power ups")
  - ruido (blanco o "8-bit", que repite muestras) filtrado (golpes, latigazos, disparos)
  - envolvente de volumen: ataque corto y caída exponencial
  - los impactos llevan 2-3 capas: click agudo + cuerpo grave + cola de ruido
En el juego cada sonido se reproduce con una variación de tono de ±7% (scripts/sonido.gd),
así los golpes repetidos no suenan "a ametralladora".
"""
import os
import wave

import numpy as np

SR = 22050
AQUI = os.path.dirname(os.path.abspath(__file__))
SALIDA = os.path.join(AQUI, "..", "audio", "sfx")
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- bloques básicos
def t(dur):
    return np.arange(int(SR * dur)) / SR


def barrido(f0, f1, dur, curva=1.0):
    x = np.linspace(0, 1, int(SR * dur)) ** curva
    return f0 + (f1 - f0) * x


def fase(freqs):
    return np.cumsum(freqs) / SR


def cuadrada(freqs, duty=0.5):
    return np.where((fase(freqs) % 1.0) < duty, 1.0, -1.0)


def triangular(freqs):
    p = fase(freqs) % 1.0
    return 4 * np.abs(p - 0.5) - 1


def ruido(dur, paso=1):
    """paso > 1 = ruido "8-bit" (repite cada muestra): más grave y áspero."""
    n = int(SR * dur)
    base = rng.uniform(-1, 1, n // paso + 1)
    return np.repeat(base, paso)[:n]


def envolvente(n, ataque=0.003, caida=8.0):
    x = np.arange(n) / SR
    env = np.exp(-x * caida)
    a = int(SR * ataque)
    if a > 0:
        env[:a] *= np.linspace(0, 1, a)
    return env


def pasa_bajos(x, corte):
    """filtro de un polo; corte puede ser un número o un array (barrido de filtro)."""
    corte = np.broadcast_to(np.asarray(corte, float), x.shape)
    a = np.exp(-2 * np.pi * corte / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def pasa_altos(x, corte):
    return x - pasa_bajos(x, corte)


def mezclar(*capas):
    n = max(len(c) for c in capas)
    out = np.zeros(n)
    for c in capas:
        out[:len(c)] += c
    return out


def notas(lista, onda="cuadrada", duty=0.5, caida=6.0, vol=1.0, legato=0.92):
    """lista = [(frecuencia o 0 para silencio, duración), ...]"""
    partes = []
    for f, d in lista:
        n = int(SR * d)
        if f <= 0:
            partes.append(np.zeros(n))
            continue
        fr = np.full(n, float(f))
        s = cuadrada(fr, duty) if onda == "cuadrada" else triangular(fr)
        env = envolvente(n, 0.002, caida)
        corte = int(n * legato)
        env[corte:] *= np.linspace(1, 0, n - corte)
        partes.append(s * env * vol)
    return np.concatenate(partes)


def nota(n):  # nota MIDI -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)


def guardar(nombre, x, vol=0.9):
    x = np.asarray(x, float)
    pico = np.max(np.abs(x)) or 1.0
    x = x / pico * vol
    # fundido de 3 ms al final para que no haga "click"
    f = min(len(x), int(SR * 0.003))
    x[-f:] *= np.linspace(1, 0, f)
    datos = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    os.makedirs(SALIDA, exist_ok=True)
    with wave.open(os.path.join(SALIDA, nombre + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos.tobytes())
    print(f"{nombre:16s} {len(x) / SR:.2f} s")


# ---------------------------------------------------------------- combate
def latigazo(dur, f0, f1, cuerpo=0.0):
    """whoosh de la lanza / sable: ruido con filtro que barre."""
    n = int(SR * dur)
    env = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    x = pasa_bajos(ruido(dur), barrido(f0, f1, dur)) * env
    if cuerpo:
        x += cuadrada(barrido(f1 * 0.12, f0 * 0.08, dur), 0.25) * env * cuerpo
    return pasa_altos(x, 150)


def impacto(dur, grave, caida, crunch=0.0):
    n = int(SR * dur)
    click = ruido(0.012) * envolvente(int(SR * 0.012), 0.0, 260)
    cuerpo = cuadrada(barrido(grave, grave * 0.45, dur, 0.5), 0.5) * envolvente(n, 0.001, caida)
    cola = pasa_bajos(ruido(dur, 3), 2500) * envolvente(n, 0.0, caida * 1.6)
    capas = [click * 0.9, cuerpo * 0.75, cola * 0.6]
    if crunch:
        cr = pasa_altos(ruido(dur * 0.6, 2), 1200) * envolvente(int(SR * dur * 0.6), 0.0, 22) * crunch
        capas.append(cr)
    return mezclar(*capas)


def generar():
    # --- el Chacho y su lanza (3 golpes del combo, cada uno más pesado)
    guardar("lanza_1", latigazo(0.13, 5500, 1400), 0.6)
    guardar("lanza_2", latigazo(0.17, 4500, 900, cuerpo=0.15), 0.65)
    guardar("lanza_3", latigazo(0.24, 6500, 600, cuerpo=0.3), 0.75)
    guardar("golpe", impacto(0.13, 170, 30), 0.85)
    guardar("golpe_fuerte", impacto(0.3, 120, 14, crunch=0.6), 0.95)
    clang = mezclar(
        cuadrada(np.full(int(SR * 0.3), 1180.0), 0.3) * envolvente(int(SR * 0.3), 0.0, 14) * 0.5,
        cuadrada(np.full(int(SR * 0.3), 1663.0), 0.5) * envolvente(int(SR * 0.3), 0.0, 18) * 0.35,
        ruido(0.02) * envolvente(int(SR * 0.02), 0.0, 200) * 0.8)
    guardar("bloqueo", clang, 0.7)
    dolor = cuadrada(barrido(620, 210, 0.2), 0.25) * envolvente(int(SR * 0.2), 0.002, 9)
    dolor *= 1 + 0.25 * np.sin(2 * np.pi * 38 * t(0.2))
    guardar("chacho_dolor", dolor, 0.6)
    muere = mezclar(notas([(nota(67), .14), (nota(63), .14), (nota(60), .14), (nota(55), .5)], duty=0.25, caida=3),
                    impacto(0.3, 90, 10) * 0.6)
    guardar("chacho_muere", muere, 0.75)

    # --- Quiroga y su sable (latigazo + "shing" metálico)
    def sable(dur, f0, f1, brillo, cuerpo=0.0):
        n = int(SR * dur)
        shing = mezclar(cuadrada(np.full(n, brillo), 0.25) * envolvente(n, 0.004, 22) * 0.18,
                        cuadrada(np.full(n, brillo * 1.5), 0.5) * envolvente(n, 0.004, 30) * 0.10)
        return mezclar(latigazo(dur, f0, f1, cuerpo=cuerpo), shing)
    guardar("sable_1", sable(0.14, 7500, 2000, 2637), 0.6)
    guardar("sable_2", sable(0.15, 6500, 1700, 2349), 0.62)
    guardar("sable_3", sable(0.26, 8000, 700, 1976, cuerpo=0.3), 0.78)
    # --- ulti de Quiroga: rugido del TIGRE DE LOS LLANOS
    dur = 0.95
    n = int(SR * dur)
    vibrato = 1 + 0.12 * np.sin(2 * np.pi * 23 * t(dur)) + 0.05 * rng.standard_normal(n).cumsum() / np.sqrt(n)
    tono = barrido(150, 75, dur, 0.7) * vibrato
    gru = cuadrada(tono, 0.3) * 0.7 + cuadrada(tono * 1.01, 0.5) * 0.4
    env = np.minimum(1, np.arange(n) / (SR * 0.12)) * np.exp(-np.maximum(0, np.arange(n) / SR - 0.35) * 4)
    ruido_garganta = pasa_bajos(ruido(dur, 2), 1800) * 0.7
    rugido = pasa_bajos(gru + ruido_garganta, barrido(2500, 900, dur)) * env
    guardar("tigre", mezclar(rugido, latigazo(0.3, 6000, 900) * 0.5), 0.95)

    # --- intro: trueno (el rayo que despierta a la estatua) y piedra que se quiebra
    dur = 2.2
    n = int(SR * dur)
    estallido = ruido(0.08) * envolvente(int(SR * 0.08), 0.0, 40)
    retumbe = pasa_bajos(ruido(dur, 6), barrido(1400, 120, dur, 0.5)) * envolvente(n, 0.01, 1.6)
    retumbe *= 1 + 0.5 * np.sin(2 * np.pi * 3.0 * t(dur)) * np.exp(-t(dur) * 1.2)
    guardar("trueno", mezclar(estallido * 0.9, retumbe * 1.2), 0.95)
    quiebre = [pasa_altos(ruido(0.05, 2), 600) * envolvente(int(SR * 0.05), 0, 60)]
    for k in range(7):
        d_ = 0.04
        q = pasa_altos(ruido(d_, 3), 900) * envolvente(int(SR * d_), 0, 70) * rng.uniform(0.3, 0.7)
        quiebre.append(np.concatenate([np.zeros(int(SR * (0.05 + 0.06 * k + rng.uniform(0, 0.03)))), q]))
    guardar("piedra", mezclar(*quiebre), 0.75)

    # --- rabia
    lista = notas([(nota(n), 0.055) for n in (60, 64, 67, 72, 76, 79, 84)], duty=0.25, caida=4, legato=1.0)
    guardar("rabia_lista", lista, 0.6)
    dur = 0.85
    ruge = mezclar(
        cuadrada(barrido(90, 420, dur, 0.6), 0.5) * envolvente(int(SR * dur), 0.02, 2.5) * 0.6,
        pasa_bajos(ruido(dur, 2), barrido(600, 5000, dur)) * envolvente(int(SR * dur), 0.01, 3) * 0.6,
        impacto(0.35, 80, 9) * 0.8)
    guardar("rabia", ruge, 0.95)

    # --- enemigos
    guardar("espadazo", latigazo(0.12, 8000, 2500), 0.5)
    culata = mezclar(impacto(0.1, 140, 38) * 0.8, ruido(0.03, 4) * envolvente(int(SR * 0.03), 0, 90) * 0.4)
    guardar("culatazo", culata, 0.55)
    dur = 0.45
    tiro = mezclar(
        ruido(0.03) * envolvente(int(SR * 0.03), 0.0, 120),
        pasa_bajos(ruido(dur, 2), barrido(6000, 400, dur, 0.4)) * envolvente(int(SR * dur), 0.0, 9),
        cuadrada(barrido(160, 45, 0.18), 0.5) * envolvente(int(SR * 0.18), 0.0, 20) * 0.7)
    guardar("disparo", tiro, 0.8)
    aviso = triangular(np.full(int(SR * 0.09), nota(93))) * envolvente(int(SR * 0.09), 0.0, 40)
    guardar("aviso_enemigo", aviso, 0.35)
    cae = mezclar(pasa_bajos(ruido(0.3, 4), 900) * envolvente(int(SR * 0.3), 0.003, 13),
                  cuadrada(barrido(95, 50, 0.2), 0.5) * envolvente(int(SR * 0.2), 0.0, 18) * 0.5)
    guardar("enemigo_cae", cae, 0.7)

    # --- items
    guardar("comer", notas([(nota(72), .06), (nota(79), .06), (nota(84), .11)], duty=0.5, caida=7), 0.5)
    glu = []
    for f in (220, 180, 240, 200):
        d = 0.07
        s = triangular(barrido(f, f * 1.6, d)) * envolvente(int(SR * d), 0.004, 20)
        glu.append(s)
    guardar("vino", mezclar(np.concatenate(glu), notas([(0, .2), (nota(76), .05), (nota(83), .12)], duty=0.25, vol=0.6)), 0.55)
    guardar("harina", notas([(nota(83), .07), (nota(88), .22)], duty=0.5, caida=7, legato=1.0), 0.45)

    # --- barriles
    madera = mezclar(triangular(barrido(420, 300, 0.12)) * envolvente(int(SR * 0.12), 0.0, 35),
                     ruido(0.015) * envolvente(int(SR * 0.015), 0.0, 220) * 0.6,
                     cuadrada(barrido(180, 120, 0.08), 0.5) * envolvente(int(SR * 0.08), 0, 45) * 0.4)
    guardar("barril_golpe", madera, 0.7)
    rompe = [impacto(0.25, 130, 14) * 0.7]
    for k in range(6):  # astillas
        d = 0.05
        astilla = pasa_altos(ruido(d, 2), 800) * envolvente(int(SR * d), 0, 50)
        rompe.append(np.concatenate([np.zeros(int(SR * (0.03 + 0.045 * k))), astilla * rng.uniform(0.3, 0.6)]))
    guardar("barril_rompe", mezclar(*rompe), 0.85)

    # --- menú e interfaz
    guardar("menu_mover", notas([(nota(84), .045)], duty=0.25, caida=30), 0.35)
    guardar("menu_aceptar", notas([(nota(72), .05), (nota(79), .05), (nota(84), .12)], duty=0.25, caida=8), 0.5)
    guardar("menu_volver", notas([(nota(79), .05), (nota(72), .09)], duty=0.25, caida=12), 0.4)
    guardar("logo", mezclar(impacto(0.4, 100, 8, crunch=0.5), latigazo(0.2, 7000, 800) * 0.5), 0.9)

    # --- avisos del nivel
    guardar("adelante", notas([(nota(81), .08), (0, .05), (nota(81), .08), (0, .05), (nota(88), .16)], duty=0.5, caida=6), 0.45)
    sirena = []
    for _ in range(3):
        sirena.append(cuadrada(barrido(520, 880, 0.22), 0.5) * envolvente(int(SR * 0.22), 0.01, 2))
        sirena.append(cuadrada(barrido(880, 520, 0.22), 0.5) * envolvente(int(SR * 0.22), 0.01, 2))
    guardar("jefe", np.concatenate(sirena) * np.linspace(1, 0.6, len(np.concatenate(sirena))), 0.45)

    # --- jingles (la música se corta y suenan estos)
    melodia = [(nota(67), .12), (nota(72), .12), (nota(76), .12), (nota(79), .24), (nota(76), .12), (nota(79), .5)]
    bajo = [(nota(48), .36), (nota(55), .36), (nota(48), .5)]
    guardar("nivel_completo", mezclar(notas(melodia, duty=0.5, caida=3), notas(bajo, "tri", caida=1.5, vol=0.8)), 0.6)
    melodia = [(nota(72), .1), (nota(72), .1), (nota(72), .1), (nota(72), .3), (nota(68), .3), (nota(70), .3),
               (nota(72), .2), (nota(70), .1), (nota(72), .8)]
    bajo = [(nota(48), .6), (nota(44), .3), (nota(46), .3), (nota(48), 1.1)]
    guardar("victoria", mezclar(notas(melodia, duty=0.5, caida=2.5), notas(bajo, "tri", caida=1, vol=0.8)), 0.6)
    melodia = [(nota(67), .25), (nota(66), .25), (nota(65), .25), (nota(64), .9)]
    bajo = [(nota(43), .5), (nota(41), .5), (nota(36), .9)]
    guardar("game_over", mezclar(notas(melodia, duty=0.25, caida=1.8), notas(bajo, "tri", caida=1.2, vol=0.8)), 0.6)


if __name__ == "__main__":
    generar()
