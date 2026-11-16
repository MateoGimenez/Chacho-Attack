extends Node
## Ajusta la ventana al tamaño de la pantalla al arrancar.
## Elige la ventana más grande que entra, siempre múltiplo exacto de 240x135
## (así el pixel art no se deforma): 1440x810 en un monitor grande, 1200x675 en una notebook.

const BASE := Vector2i(240, 135)
const ESCALA_MAX := 6       # 6 = 1440x810, el tamaño original del proyecto
const MARGEN := Vector2i(0, 36)  # lugar para la barra de título y la barra de tareas


func _ready() -> void:
	# en la web, en el celular o en pantalla completa no hace falta
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	# si el juego corre adentro del editor, la ventana la maneja el editor
	if Engine.is_embedded_in_editor():
		return
	var pantalla := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var lugar := pantalla.size - MARGEN
	var escala := clampi(mini(lugar.x / BASE.x, lugar.y / BASE.y), 1, ESCALA_MAX)
	var tam := BASE * escala
	DisplayServer.window_set_size(tam)
	DisplayServer.window_set_position(pantalla.position + Vector2i((pantalla.size.x - tam.x) / 2, maxi(32, (pantalla.size.y - tam.y + 32) / 2)))
