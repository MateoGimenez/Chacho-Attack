extends Node
## Registra todos los controles del juego (teclado + joystick). Es un "autoload".
## Para cambiar una tecla, editá las listas de abajo.
##
## 1 JUGADOR: todo controla al jugador 1 (WASD o flechas, J/K/L, Shift y cualquier joystick).
## 2 JUGADORES (Entradas.configurar(true), lo llama el menú):
##   J1 → WASD, C lanza/sable, V bloquear, B rabia, Shift izquierdo correr, joystick 1
##   J2 → flechas, K lanza/sable, L bloquear, Ñ rabia, Shift derecho correr
##        (o teclado numérico: 1 / 2 / 3 / 0), joystick 2
## Las acciones del jugador 2 son las mismas con "_2" al final (atacar_2, mover_izq_2...).

const ACCIONES := ["mover_izq", "mover_der", "mover_arriba", "mover_abajo", "atacar", "bloquear", "correr", "especial"]

const TECLAS_1_JUGADOR := {
	"mover_izq": [KEY_A, KEY_LEFT],
	"mover_der": [KEY_D, KEY_RIGHT],
	"mover_arriba": [KEY_W, KEY_UP],
	"mover_abajo": [KEY_S, KEY_DOWN],
	"atacar": [KEY_J, KEY_Z],          # lanzazo (apretá varias veces = combo)
	"bloquear": [KEY_K, KEY_X],        # mantener apretado
	"correr": [KEY_SHIFT],             # mantener apretado
	"especial": [KEY_L, KEY_C],        # activa la RABIA (con la barra llena)
}

const TECLAS_J1 := {
	"mover_izq": [KEY_A], "mover_der": [KEY_D], "mover_arriba": [KEY_W], "mover_abajo": [KEY_S],
	"atacar": [KEY_C], "bloquear": [KEY_V], "especial": [KEY_B], "correr": [-KEY_SHIFT],  # negativo = solo el izquierdo
}

const TECLAS_J2 := {
	"mover_izq": [KEY_LEFT], "mover_der": [KEY_RIGHT], "mover_arriba": [KEY_UP], "mover_abajo": [KEY_DOWN],
	"atacar": [KEY_K, KEY_KP_1], "bloquear": [KEY_L, KEY_KP_2], "especial": [KEY_SEMICOLON, KEY_KP_3],  # Ñ = tecla ";"
	"correr": [KEY_SHIFT, KEY_KP_0],   # KEY_SHIFT acá = solo el derecho
}

## Para mostrar en pantalla qué tecla activa la rabia
const TECLA_RABIA := {0: "L", 1: "B", 2: "Ñ"}

const BOTONES_JOYSTICK := {
	"atacar": JOY_BUTTON_X,
	"bloquear": JOY_BUTTON_B,
	"correr": JOY_BUTTON_RIGHT_SHOULDER,
	"especial": JOY_BUTTON_Y,
}

var dos_jugadores := false


func _ready() -> void:
	_accion("pausa", 0.5)
	for t in [KEY_ESCAPE, KEY_P]:
		_tecla("pausa", t)
	_boton("pausa", JOY_BUTTON_START, -1)
	# El botón A del joystick también confirma en los menús
	_boton("ui_accept", JOY_BUTTON_A, -1)
	configurar(false)


## Arma los controles para 1 o 2 jugadores
func configurar(dos: bool) -> void:
	dos_jugadores = dos
	for sufijo in ["", "_2"]:
		for a: String in ACCIONES:
			_accion(a + sufijo, 0.2)
			InputMap.action_erase_events(a + sufijo)
	if not dos:
		for a: String in TECLAS_1_JUGADOR:
			for t: int in TECLAS_1_JUGADOR[a]:
				_tecla(a, t)
		_joystick("", -1)  # cualquier joystick
		return
	for a: String in TECLAS_J1:
		for t: int in TECLAS_J1[a]:
			if t < 0:
				_tecla(a, -t, KEY_LOCATION_LEFT)
			else:
				_tecla(a, t)
	for a: String in TECLAS_J2:
		for t: int in TECLAS_J2[a]:
			_tecla(a + "_2", t, KEY_LOCATION_RIGHT if t == KEY_SHIFT else KEY_LOCATION_UNSPECIFIED)
	_joystick("", 0)
	_joystick("_2", 1)


## Texto de la tecla de rabia para el HUD: jugador 1 o 2
func tecla_rabia(numero: int) -> String:
	if not dos_jugadores:
		return TECLA_RABIA[0]
	return TECLA_RABIA[numero]


func _accion(nombre: String, zona_muerta: float) -> void:
	if not InputMap.has_action(nombre):
		InputMap.add_action(nombre, zona_muerta)


func _tecla(accion: String, tecla: int, lado := KEY_LOCATION_UNSPECIFIED) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	ev.location = lado
	InputMap.action_add_event(accion, ev)


func _boton(accion: String, boton: JoyButton, dispositivo: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = boton
	ev.device = dispositivo
	InputMap.action_add_event(accion, ev)


func _joystick(sufijo: String, dispositivo: int) -> void:
	for accion: String in BOTONES_JOYSTICK:
		_boton(accion + sufijo, BOTONES_JOYSTICK[accion], dispositivo)
	# palanca izquierda y cruceta
	for d in [["mover_izq", JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT],
			["mover_der", JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT],
			["mover_arriba", JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP],
			["mover_abajo", JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN]]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = d[1]
		ev.axis_value = d[2]
		ev.device = dispositivo
		InputMap.action_add_event(d[0] + sufijo, ev)
		_boton(d[0] + sufijo, d[3], dispositivo)
