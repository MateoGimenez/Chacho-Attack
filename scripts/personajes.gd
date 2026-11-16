class_name Personajes
## Los personajes jugables: cómo se ven, su combo y su ulti.
## El Chacho usa su SpriteFrames (recursos/chacho_frames.tres).
## Quiroga se arma desde su hoja (sprites/quiroga_16px.png, misma grilla que los enemigos:
## 8 columnas x 6 filas de 64x48), que sale de fuentes/gen_quiroga.py.
##
## En cada golpe del combo:
##  frame = en qué cuadro de la animación pega | alcance = largo del arma en píxeles
##  profundidad = tolerancia arriba/abajo | altura = a qué altura se dibuja la estela
##  ambos = pega a los dos lados | avance = cuánto se adelanta el cuerpo al pegar

const DATOS := {
	"chacho": {
		"nombre": "CHACHO",
		"arma": "LANZA",
		"offset": Vector2(0, -17.5),
		"sonido": "lanza_%d",
		"grito": "¡RABIA RIOJANA!",
		"ulti": "remolino",
		"combo": [
			{"anim": &"estocada", "frame": 2, "danio": 9, "fuerza": 25.0, "vel": 1.15,
				"alcance": 29.0, "profundidad": 7.0, "ambos": false, "altura": 18.0, "avance": 22.5, "tajo": &"estocada"},
			{"anim": &"barrido", "frame": 1, "danio": 11, "fuerza": 35.0, "vel": 1.15,
				"alcance": 26.0, "profundidad": 8.0, "ambos": true, "altura": 14.0, "avance": 10.0, "tajo": &"barrido"},
			{"anim": &"estocada_larga", "frame": 1, "danio": 20, "fuerza": 120.0, "vel": 1.0,
				"alcance": 36.0, "profundidad": 7.0, "ambos": false, "altura": 16.0, "avance": 60.0, "tajo": &"estocada"},
		],
		## RABIA RIOJANA: barrido gigante alrededor
		"especial": {"anim": &"barrido", "frame": 1, "danio": 40, "fuerza": 150.0, "vel": 0.8,
			"alcance": 60.0, "profundidad": 24.0, "ambos": true, "altura": 14.0, "avance": 0.0, "tajo": &"barrido"},
	},
	"quiroga": {
		"nombre": "QUIROGA",
		"arma": "SABLE",
		"offset": Vector2(0, -21),
		"sonido": "sable_%d",
		"grito": "¡TIGRE DE LOS LLANOS!",
		"ulti": "embestida",
		## corte → revés → mandoble (de arriba para abajo, el que hace volar)
		"combo": [
			{"anim": &"tajo", "frame": 1, "danio": 8, "fuerza": 25.0, "vel": 1.2,
				"alcance": 26.0, "profundidad": 8.0, "ambos": false, "altura": 20.0, "avance": 15.0, "tajo": &"barrido"},
			{"anim": &"reves", "frame": 1, "danio": 10, "fuerza": 35.0, "vel": 1.25,
				"alcance": 26.0, "profundidad": 8.0, "ambos": false, "altura": 18.0, "avance": 12.0, "tajo": &"barrido"},
			{"anim": &"mandoble", "frame": 2, "danio": 22, "fuerza": 120.0, "vel": 1.05,
				"alcance": 30.0, "profundidad": 9.0, "ambos": false, "altura": 24.0, "avance": 30.0, "tajo": &"barrido"},
		],
		## TIGRE DE LOS LLANOS: embestida que cruza la pantalla y zarpa a todos los del carril
		"especial": {"danio": 35, "fuerza": 150.0, "distancia": 110.0, "duracion": 0.42,
			"profundidad": 13.0, "ancho": 18.0},
	},
}

## Quiroga: [animación, fila de la hoja, cuadros, cuadros por segundo, se repite, duraciones {cuadro: x}]
const ANIMS_QUIROGA := [
	["quieto", 0, [0, 1, 2, 3], 6.0, true, {}],
	["caminar", 1, [0, 1, 2, 3, 4, 5], 10.0, true, {}],
	["correr", 2, [0, 1, 2, 3, 4, 5], 15.0, true, {}],
	["tajo", 3, [0, 1, 2], 12.0, false, {0: 1.5, 1: 1.5}],
	["reves", 3, [2, 1, 0], 12.0, false, {1: 1.5, 2: 1.5}],
	["mandoble", 3, [3, 4, 5, 6], 12.0, false, {0: 1.5, 1: 2.0, 2: 1.8, 3: 1.2}],
	["bloqueo", 2, [4], 1.0, true, {}],
	["embestida", 2, [4, 5], 14.0, true, {}],
	["dolor", 4, [0], 10.0, false, {0: 3.0}],
	["muerte", 5, [0, 1, 2, 3, 4, 5], 10.0, false, {5: 6.0}],
]
const CUADRO := Vector2i(64, 48)

static var _cache := {}


static func datos(id: String) -> Dictionary:
	return DATOS.get(id, DATOS["chacho"])


static func frames(id: String) -> SpriteFrames:
	if _cache.has(id):
		return _cache[id]
	var sf: SpriteFrames
	if id == "quiroga":
		sf = _frames_desde_hoja(load("res://sprites/quiroga_16px.png"), ANIMS_QUIROGA)
	else:
		sf = load("res://recursos/chacho_frames.tres")
	_cache[id] = sf
	return sf


static func _frames_desde_hoja(hoja: Texture2D, anims: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for d: Array in anims:
		var nombre: String = d[0]
		sf.add_animation(nombre)
		sf.set_animation_speed(nombre, d[3])
		sf.set_animation_loop(nombre, d[4])
		var dur: Dictionary = d[5]
		var i := 0
		for c: int in d[2]:
			var at := AtlasTexture.new()
			at.atlas = hoja
			at.region = Rect2(c * CUADRO.x, int(d[1]) * CUADRO.y, CUADRO.x, CUADRO.y)
			sf.add_frame(nombre, at, dur.get(i, 1.0))
			i += 1
	return sf
