extends CanvasLayer
## Controles en pantalla para celular: joystick a la izquierda y 4 botones a la derecha.
## Solo aparecen si el dispositivo tiene pantalla táctil.
## Los botones "aprietan" las mismas acciones que el teclado, así que el
## Chacho no sabe si lo controlás con teclado, joystick o con el dedo.

## Activalo para ver los controles en la PC mientras los acomodás
@export var forzar_visible := false

## [acción, imagen, posición (esquina superior izquierda)] — pantalla de 240x135
## El texto de cada botón ya viene dibujado en la imagen (fuente pixel 3x5, ver fuentes/gen_16px.py).
const BOTONES := [
	["atacar", "boton_lanza", Vector2(206, 99)],
	["bloquear", "boton_bloqueo", Vector2(181, 110)],
	["correr", "boton_correr", Vector2(181, 85)],
	["especial", "boton_poder", Vector2(210, 72)],
]


func _ready() -> void:
	layer = 5
	visible = forzar_visible or DisplayServer.is_touchscreen_available()
	if not visible:
		return
	for datos in BOTONES:
		_crear_boton(datos[0], datos[1], datos[2])
	var joy := Joystick.new()
	joy.position = Vector2(30, 106)
	add_child(joy)


func _crear_boton(accion: String, imagen: String, pos: Vector2) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = load("res://sprites/ui/%s.png" % imagen)
	b.texture_pressed = load("res://sprites/ui/%s_apretado.png" % imagen)
	b.action = accion
	b.position = pos
	var d := b.texture_normal.get_width()
	var forma := CircleShape2D.new()
	forma.radius = d * 0.6  # un poco más grande que el dibujo: más fácil de tocar
	b.shape = forma
	add_child(b)


## Joystick virtual: arrastrás el dedo y aprieta las acciones de movimiento
class Joystick extends Node2D:
	var radio := 17.0
	var dedo := -1
	var palanca := Vector2.ZERO

	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var local := make_input_local(event) as InputEventScreenTouch
			if event.pressed and dedo == -1 and local.position.length() < radio * 2.2:
				dedo = event.index
				_mover(local.position)
			elif not event.pressed and event.index == dedo:
				dedo = -1
				_mover(Vector2.ZERO)
		elif event is InputEventScreenDrag and event.index == dedo:
			var local := make_input_local(event) as InputEventScreenDrag
			_mover(local.position)

	func _mover(p: Vector2) -> void:
		palanca = p.limit_length(radio) / radio
		_accion("mover_izq", -palanca.x)
		_accion("mover_der", palanca.x)
		_accion("mover_arriba", -palanca.y)
		_accion("mover_abajo", palanca.y)
		queue_redraw()

	func _accion(nombre: String, fuerza: float) -> void:
		if fuerza > 0.2:
			Input.action_press(nombre, fuerza)
		else:
			Input.action_release(nombre)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radio, Color(0, 0, 0, 0.3))
		draw_arc(Vector2.ZERO, radio, 0.0, TAU, 32, Color(1, 0.94, 0.86, 0.45), 1.0)
		draw_circle((palanca * radio).round(), 7.0, Color(1, 0.94, 0.86, 0.55))
