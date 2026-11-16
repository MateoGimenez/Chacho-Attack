extends Node
## Datos de la partida que pasan de un nivel al otro (vida, puntos, rabia de cada jugador)
## y la configuración de los 3 niveles. Es un "autoload": existe siempre.
##
## Para agregar un nivel: copiá uno de los bloques de NIVELES y cambiá los datos.

## Cómo es el piso de cada escenario:
##  piso_arriba / piso_abajo = franja donde se puede caminar (Y en píxeles, pantalla de 135 de alto: grilla de 16px)
##  zonas = tipos de piso de arriba hacia abajo. "hasta_y" = dónde termina esa zona.
##          "polvo" = colores de lo que se levanta al caminar.
##          "golpe" = colores de lo que salta cuando un golpe entra.
##  barriles = [x, y] de cada barril (sueltan comida al romperse)
##  items = [x, y, tipo] items sueltos en el piso

const NIVELES := [
	{
		"nombre": "LA CATEDRAL",
		"subtitulo": "NIVEL 1 · CENTRO",
		"fondo": "res://sprites/fondos/catedral.png", "musica": "catedral",
		"piso_arriba": 93.0, "piso_abajo": 131.0,
		"zonas": [
			{"nombre": "vereda", "hasta_y": 99.0,
				"polvo": [Color("#c9c2b6"), Color("#a59e93")], "golpe": [Color("#e8e2d6"), Color("#b2aba0")]},
			{"nombre": "asfalto", "hasta_y": 999.0,
				"polvo": [Color("#6c6c76"), Color("#8a8a92")], "golpe": [Color("#9a9aa3"), Color("#4d4d57")]},
		],
		"oleadas": [
			{"x": 150.0, "enemigos": [["soldado", 1], ["soldado", 1]]},
			{"x": 190.0, "enemigos": [["soldado", 1], ["soldado", 1]]},
			{"x": 380.0, "enemigos": [["soldado", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 625.0, "enemigos": [["sargento", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 655.0, "enemigos": [["sargento", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 780.0, "enemigos": [["sargento", 1], ["soldado", -1], ["soldado", 1], ["soldado", -1]],
				"mensaje": "¡DEFENDÉ LA PLAZA!"},
			# JEFE: Paz (scripts/jefe_paz.gd). "mensaje" y "sub" = la presentación.
			{"x": 875.0, "enemigos": [["paz", 1]], "mensaje": "GRAL. JOSE MARIA PAZ", "sub": "EL MANCO"},
		],
		"barriles": [[215.0, 103.0], [490.0, 123.0], [590.0, 100.0], [750.0, 115.0]],
		"items": [[350.0, 113.0, Item.Tipo.VINO]],
	},
	{
		"nombre": "EL SUPERDOMO",
		"subtitulo": "NIVEL 2 · ATARDECER",
		"fondo": "res://sprites/fondos/superdomo.png", "musica": "superdomo",
		"piso_arriba": 97.0, "piso_abajo": 131.0,
		"zonas": [
			{"nombre": "baldosas", "hasta_y": 999.0,
				"polvo": [Color("#d8ccb8"), Color("#b6a68e")], "golpe": [Color("#f0e6d4"), Color("#9c4e3c")]},
		],
		"oleadas": [
			{"x": 150.0, "enemigos": [["soldado", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 170.0, "enemigos": [["soldado", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 190.0, "enemigos": [["soldado", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 220.0, "enemigos": [["soldado", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 380.0, "enemigos": [["sargento", 1], ["soldado", 1], ["soldado", -1]]},
			{"x": 600.0, "enemigos": [["sargento", 1], ["sargento", -1], ["soldado", 1]]},
			{"x": 780.0, "enemigos": [["soldado", 1], ["soldado", -1], ["sargento", 1], ["soldado", -1]],
				"mensaje": "¡ÚLTIMA OLEADA!"},
			# JEFES: el dúo (scripts/jefe_rivadavia.gd y jefe_rosas.gd), comparten una barra
			{"x": 875.0, "enemigos": [["rivadavia", 1], ["rosas", 1]], "mensaje": "RIVADAVIA Y ROSAS",
				"sub": "EL DUO DEL DOMO"},
		],
		"barriles": [[200.0, 118.0], [310.0, 103.0], [500.0, 125.0], [710.0, 108.0], [790.0, 123.0]],
		"items": [[260.0, 120.0, Item.Tipo.VINO], [550.0, 110.0, Item.Tipo.VINO]],
	},
	{
		"nombre": "LA CHAYA",
		"subtitulo": "NIVEL 3 · NOCHE DE CHAYA",
		"fondo": "res://sprites/fondos/chaya.png", "musica": "chaya",
		"piso_arriba": 96.0, "piso_abajo": 131.0,
		"zonas": [
			# En la Chaya el piso está lleno de harina y albahaca: cada golpe levanta una nube
			{"nombre": "tierra con harina", "hasta_y": 999.0,
				"polvo": [Color("#8a6250"), Color("#fff6ea"), Color("#f3ece0")],
				"golpe": [Color("#ffffff"), Color("#f3ece0"), Color("#fff6ea"), Color("#5bbf5a")]},
		],
		"oleadas": [
			{"x": 150.0, "enemigos": [["soldado", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 170.0, "enemigos": [["soldado", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 190.0, "enemigos": [["soldado", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 220.0, "enemigos": [["soldado", 1], ["soldado", -1], ["soldado", 1]]},
			{"x": 380.0, "enemigos": [["sargento", 1], ["sargento", -1], ["soldado", 1]]},
			{"x": 600.0, "enemigos": [["soldado", 1], ["soldado", -1], ["sargento", 1], ["soldado", -1]]},
			# mini jefe: el Coronel (barra arriba, pero no termina el nivel)
			{"x": 760.0, "enemigos": [["coronel", 1], ["soldado", -1]], "mensaje": "¡EL CORONEL!"},
			# JEFE FINAL (scripts/jefe_final.gd). Nombre y sprite provisorios: se cambian en TIPOS de nivel.gd
			{"x": 875.0, "enemigos": [["tesorero", 1]], "mensaje": "EL TESORERO", "sub": "Y SU CUSTODIA"},
		],
		"barriles": [[210.0, 110.0], [440.0, 125.0], [540.0, 103.0], [725.0, 120.0], [795.0, 105.0]],
		"items": [[300.0, 120.0, Item.Tipo.VINO], [650.0, 108.0, Item.Tipo.HARINA], [775.0, 128.0, Item.Tipo.VINO]],
	},
]

const VIDA_MAX := 100
## Vida que se recupera al pasar de nivel
const CURA_ENTRE_NIVELES := 30
## En 2 jugadores, el que cayó vuelve en el nivel siguiente con esta vida
const VIDA_AL_VOLVER := 50
## En 2 jugadores los enemigos tienen más vida (x1,5) y pueden atacar 3 a la vez
const VIDA_ENEMIGOS_2J := 1.5
## Los jefes en 2 jugadores tienen x1,8 (de a 2 es fácil pegarles por la espalda)
const VIDA_JEFES_2J := 1.8

var nivel := 0
var puntos := 0
## Un personaje por jugador: ["chacho"] o ["chacho", "quiroga"]
var personajes: Array = ["chacho"]
var vidas: Array = [VIDA_MAX]
var rabias: Array = [0.0]
var _al_empezar_nivel := {}  # cómo estaba todo al entrar al nivel (para reintentar)


func dos_jugadores() -> bool:
	return personajes.size() > 1


func nueva_partida(p_personajes: Array = ["chacho"]) -> void:
	personajes = p_personajes.duplicate()
	nivel = 0
	puntos = 0
	vidas = []
	rabias = []
	for p in personajes:
		vidas.append(VIDA_MAX)
		rabias.append(0.0)
	_guardar()


func config() -> Dictionary:
	return NIVELES[nivel]


func es_ultimo_nivel() -> bool:
	return nivel >= NIVELES.size() - 1


func pasar_de_nivel(p_puntos: int, p_vidas: Array, p_rabias: Array) -> void:
	puntos = p_puntos
	for i in vidas.size():
		var v: int = p_vidas[i]
		vidas[i] = VIDA_AL_VOLVER if v <= 0 else mini(v + CURA_ENTRE_NIVELES, VIDA_MAX)
		rabias[i] = p_rabias[i]
	nivel += 1
	_guardar()


## Al perder se vuelve a empezar el mismo nivel, como estaba al entrar
func reintentar_nivel() -> void:
	nivel = _al_empezar_nivel.get("nivel", 0)
	puntos = _al_empezar_nivel.get("puntos", 0)
	for i in vidas.size():
		vidas[i] = VIDA_MAX
	rabias = (_al_empezar_nivel.get("rabias", rabias) as Array).duplicate()


## Devuelve los colores de polvo/golpe según en qué zona del piso está "y"
func zona_de_piso(y: float) -> Dictionary:
	for zona: Dictionary in config()["zonas"]:
		if y <= zona["hasta_y"]:
			return zona
	return config()["zonas"][-1]


func _guardar() -> void:
	_al_empezar_nivel = {"nivel": nivel, "puntos": puntos, "rabias": rabias.duplicate()}
