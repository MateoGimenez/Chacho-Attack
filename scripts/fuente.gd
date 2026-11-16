class_name Fuente
## Fuente pixel del juego (Press Start 2P, la misma del menú).
## Se dibuja a 8 px (o 16 px para títulos): así cae justo en la grilla de 16px.
## Uso:  label.label_settings = Fuente.ajustes(8, Color.WHITE)

const RUTA := "res://menu/PressStart2P-Regular.ttf"
const C_BORDE := Color("#1a0f14")

static var _fuente: FontFile


static func fuente() -> FontFile:
	if _fuente == null:
		_fuente = load(RUTA)
		# sin suavizado: letras con bordes duros, como el pixel art
		_fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_fuente.hinting = TextServer.HINTING_NONE
		_fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _fuente


## tamanio: 8 (texto normal) o 16 (títulos). Con contorno oscuro y sombra abajo.
static func ajustes(tamanio: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = fuente()
	ls.font_size = tamanio
	ls.font_color = color
	ls.outline_size = 2 if tamanio <= 8 else 4
	ls.outline_color = C_BORDE
	ls.shadow_size = ls.outline_size
	ls.shadow_color = C_BORDE
	ls.shadow_offset = Vector2(1, 1) if tamanio <= 8 else Vector2(2, 2)
	ls.line_spacing = 2
	return ls
