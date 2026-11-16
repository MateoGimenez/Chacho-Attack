class_name EnemigoFrames
## Arma el SpriteFrames de un enemigo a partir de su hoja de 16px
## (sprites/enemigos/<id>_16px.png: 8 columnas x 6 filas, cuadros de 64x48, pies en (32, 45)).
## Los nombres de las animaciones son los que usa Luchador: quieto, caminar, guardia,
## ataque, dolor (fila "golpe") y muerte (fila "caida").
##
## Uso:  sprite.sprite_frames = EnemigoFrames.obtener("marinero")
##       sprite.offset = EnemigoFrames.OFFSET

const CUADRO := Vector2i(64, 48)
const OFFSET := Vector2(0, -21)   # así los pies quedan en la posición del nodo
const CARPETA := "res://sprites/enemigos/%s_16px.png"

## Personajes con fusil: tienen 8 cuadros de ataque (los demás 7)
const CON_FUSIL := ["miquelete", "moreno", "natural"]

## Cuadros de "ataque" que pegan: 1 = golpe / culatazo, 5 = segundo golpe o disparo
const CUADRO_GOLPE := 1
const CUADRO_DISPARO := 5

## nombre: [fila, cuadros, cuadros por segundo, se repite]
const ANIMS := {
	"quieto": [0, 4, 6.0, true],
	"caminar": [1, 6, 10.0, true],
	"guardia": [2, 6, 10.0, true],
	"ataque": [3, 7, 12.0, false],
	"dolor": [4, 1, 10.0, false],
	"muerte": [5, 6, 10.0, false],
}

## Duración relativa de algunos cuadros (1.0 = normal):
## el cuadro 0 del ataque es la anticipación (más largo, para que se pueda leer y bloquear)
const DURACIONES := {
	"ataque": {0: 4.0, 1: 1.5, 5: 1.5},
	"dolor": {0: 3.0},
	"muerte": {5: 6.0},
}

static var _cache := {}


static func obtener(personaje: String) -> SpriteFrames:
	if not _cache.has(personaje):
		_cache[personaje] = crear(load(CARPETA % personaje), personaje in CON_FUSIL)
	return _cache[personaje]


static func crear(hoja: Texture2D, fusil := false) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for nombre: String in ANIMS:
		var d: Array = ANIMS[nombre]
		var cantidad: int = d[1]
		if fusil and nombre == "ataque":
			cantidad = 8
		sf.add_animation(nombre)
		sf.set_animation_speed(nombre, d[2])
		sf.set_animation_loop(nombre, d[3])
		var dur: Dictionary = DURACIONES.get(nombre, {})
		for i in cantidad:
			var at := AtlasTexture.new()
			at.atlas = hoja
			at.region = Rect2(i * CUADRO.x, d[0] * CUADRO.y, CUADRO.x, CUADRO.y)
			sf.add_frame(nombre, at, dur.get(i, 1.0))
	return sf
