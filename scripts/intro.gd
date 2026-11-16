extends Node2D
## INTRO: la Rotonda del Chacho, de noche.
## 1. Textos de la historia en una franja negra abajo, como en el cine.
## 2. Cae un rayo sobre la estatua: brilla, se le cae la piedra y toma color.
## 3. Se achica hasta el tamaño del juego y salta del pedestal.
## 4. El jugador ya maneja al personaje: camina a la derecha y empieza el nivel 1.
## ENTER, ESC o tocar la pantalla saltean la intro (cuando ya manejás al personaje, solo ESC).
##
## Si en la partida está Quiroga, entra corriendo por la izquierda.
## Si se juega solo con Quiroga, el Chacho se adelanta corriendo y Quiroga lo sigue.

## Textos de la historia (sin tildes: la fuente pixel las dibuja mal). Cambialos acá.
const TEXTOS := [
	"LA RIOJA, 2026.",
	"UN HECHIZO SALIO MAL Y LOS FANTASMAS UNITARIOS VOLVIERON A LA CIUDAD.",
	"LA PROVINCIA ESTABA EN PELIGRO... PERO ALGUIEN VIGILABA LA ROTONDA.",
]
const TEXTO_DESPIERTA := "...Y EL CHACHO NO SE IBA A QUEDAR QUIETO."
const GRITO := "¡LA RIOJA NO SE ENTREGA!"

const ESCENA_NIVEL := "res://escenas/nivel.tscn"
const ESCENA_JUGADOR := preload("res://escenas/jugador.tscn")
const SHADER_PIEDRA := preload("res://shaders/piedra.gdshader")

const PIES_ESTATUA := Vector2(81, 73)     # tope del pedestal (sale de fuentes/gen_rotonda.py)
const ATERRIZAJE := Vector2(122, 118)
const PISO_ARRIBA := 104.0
const PISO_ABAJO := 131.0
const SALIDA_X := 236.0

var _saliendo := false
var _controlando := false
var _jugadores: Array[Node2D] = []
var _npc: AnimatedSprite2D

@onready var mundo: Node2D = $Mundo
@onready var estatua: Sprite2D = $Mundo/Estatua
@onready var camara: Camera2D = $Camara
@onready var ui: CanvasLayer = $UI
var _saltear: Label
var _barra_abajo: ColorRect
var _texto: Label
var _grande: Label
var _ayuda: Label
var _flecha: Label
var _flash: ColorRect
var _negro: ColorRect
var _rayo: Line2D
var _temblor := 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	Luchador.piso_arriba = PISO_ARRIBA
	Luchador.piso_abajo = PISO_ABAJO
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_PIEDRA
	estatua.material = mat
	_armar_ui()
	_secuencia()


# ---------------------------------------------------------------- armado
func _armar_ui() -> void:
	_barra_abajo = _rect(Color.BLACK, Rect2(0, 103, 240, 32))
	_texto = _label("", 8, Vector2(0, 106), Vector2(240, 28), Color("#fff1d6"))
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.label_settings.line_spacing = 2
	_grande = _label("", 16, Vector2(4, 26), Vector2(232, 40), Color("#f2b84b"))
	_grande.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grande.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_grande.modulate.a = 0.0
	_saltear = _label("ENTER: SALTEAR", 8, Vector2(120, 2), Vector2(116, 10), Color(1, 1, 1, 0.45))
	_saltear.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if DisplayServer.is_touchscreen_available():
		_saltear.text = "TOCA: SALTEAR"
	_ayuda = _label("", 8, Vector2(0, 124), Vector2(240, 10), Color("#fff1d6"))
	_flecha = _label("¡ADELANTE! ▶", 8, Vector2(116, 62), Vector2(120, 10), Color("#f2b84b"))
	_flecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_flecha.visible = false
	_rayo = Line2D.new()
	_rayo.width = 2.0
	_rayo.default_color = Color("#e8f4ff")
	_rayo.visible = false
	add_child(_rayo)
	_flash = _rect(Color(1, 1, 1, 0), Rect2(0, 0, 240, 135))
	_negro = _rect(Color.BLACK, Rect2(0, 0, 240, 135))


func _rect(c: Color, r: Rect2) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = c
	cr.position = r.position
	cr.size = r.size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(cr)
	return cr


func _label(t: String, tam: int, pos: Vector2, tamanio: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.label_settings = Fuente.ajustes(tam, color)
	l.position = pos
	l.size = tamanio
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(l)
	return l


# ---------------------------------------------------------------- la secuencia
func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func _secuencia() -> void:
	await _tween(_negro, "color:a", 0.0, 1.0)
	for t in TEXTOS:
		if _saliendo:
			return
		await _escribir(t)
		await _esperar(1.4)
	if _saliendo:
		return
	_texto.text = ""

	# --- el rayo
	await _caer_rayo()
	if _saliendo:
		return
	# --- la piedra se quiebra y toma color
	Sonido.tocar("piedra", 0.0, 0.0)
	_piedritas(PIES_ESTATUA + Vector2(0, -40), 18)
	_temblor = 0.4
	var mat := estatua.material as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("brillo", v), 1.0, 0.0, 0.5)
	tw.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter("piedra", v), 1.0, 0.0, 1.2)
	_escribir(TEXTO_DESPIERTA)
	await tw.finished
	await _esperar(1.0)
	if _saliendo:
		return

	# --- se achica hasta el tamaño del juego
	Sonido.tocar("rabia_lista", 0.0, 0.0)
	tw = create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("brillo", v), 0.0, 1.0, 0.15)
	tw.tween_property(estatua, "scale", Vector2(0.5, 0.5), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	estatua.visible = false
	_npc = AnimatedSprite2D.new()
	_npc.sprite_frames = Personajes.frames("chacho")
	_npc.offset = Personajes.datos("chacho")["offset"]
	_npc.position = PIES_ESTATUA
	_npc.play(&"quieto")
	mundo.add_child(_npc)
	_destello_blanco(0.25)
	await _esperar(0.5)
	if _saliendo:
		return

	# --- salta del pedestal
	_texto.text = ""
	_npc.play(&"correr")
	var desde := _npc.position
	tw = create_tween()
	tw.tween_method(func(k: float) -> void:
		_npc.position = desde.lerp(ATERRIZAJE, k) + Vector2(0, -sin(k * PI) * 22.0), 0.0, 1.0, 0.55)
	await tw.finished
	_npc.play(&"quieto")
	Sonido.tocar("logo", 0.0, 0.0)
	_temblor = 0.3
	_polvo(ATERRIZAJE)
	Musica.tocar("catedral", 1.5)   # la del nivel 1: sigue sonando al pasar a la Catedral
	_tween(_barra_abajo, "position:y", 135.0, 0.4)
	_texto.visible = false
	_grande.text = GRITO
	_grande.modulate.a = 1.0
	_grande.scale = Vector2(1.2, 1.2)
	_grande.pivot_offset = _grande.size / 2.0
	create_tween().tween_property(_grande, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	await _esperar(1.4)
	_tween(_grande, "modulate:a", 0.0, 0.3)
	if _saliendo:
		return
	await _dar_control()


## Texto que se escribe de a una letra (como máquina de escribir)
func _escribir(t: String) -> void:
	_texto.text = t
	_texto.visible_characters = 0
	for i in t.length():
		if _saliendo:
			return
		_texto.visible_characters = i + 1
		if t[i] != " " and i % 2 == 0:
			Sonido.tocar("menu_mover", -14.0, 0.15)
		await _esperar(0.035)


func _caer_rayo() -> void:
	var cabeza := PIES_ESTATUA + Vector2(-2, -62)
	var puntos := PackedVector2Array([Vector2(cabeza.x + 30, -4)])
	var y := -4.0
	var x := cabeza.x + 30
	while y < cabeza.y:
		y += randf_range(8, 14)
		x += randf_range(-9, 6) + (cabeza.x - x) * 0.25
		puntos.append(Vector2(roundf(x), roundf(minf(y, cabeza.y))))
	_rayo.points = puntos
	Sonido.tocar("trueno", 0.0, 0.0)
	for i in 3:
		_rayo.visible = true
		_destello_blanco(0.12)
		await _esperar(0.07)
		_rayo.visible = false
		await _esperar(0.06)
	var mat := estatua.material as ShaderMaterial
	mat.set_shader_parameter("brillo", 1.0)
	_temblor = 0.6
	await _esperar(0.6)


func _destello_blanco(duracion: float) -> void:
	_flash.color = Color(1, 1, 1, 0.85)
	create_tween().tween_property(_flash, "color:a", 0.0, duracion)


# ---------------------------------------------------------------- control del jugador
func _dar_control() -> void:
	var personajes: Array = Juego.personajes
	var tiene_chacho := "chacho" in personajes
	for i in personajes.size():
		var j := ESCENA_JUGADOR.instantiate() as Node2D
		j.set("personaje", personajes[i])
		j.set("numero", i + 1)
		if personajes[i] == "chacho":
			j.position = ATERRIZAJE
		else:
			j.position = Vector2(-14, 124)
		mundo.add_child(j)
		j.set("vida", Juego.vidas[i])
		_jugadores.append(j)
	if tiene_chacho:
		_npc.queue_free()
		_npc = null
	else:
		# jugando solo con Quiroga: el Chacho se adelanta corriendo
		_npc.flip_h = false
		_npc.play(&"correr")
		create_tween().tween_property(_npc, "position:x", 270.0, 1.2)
	# Quiroga entra corriendo por la izquierda (sin control hasta llegar)
	for j in _jugadores:
		if j.get("personaje") == "quiroga":
			j.set_physics_process(false)
			var spr := j.get("sprite") as AnimatedSprite2D
			spr.play(&"correr")
			var tw := create_tween()
			tw.tween_property(j, "position:x", 70.0, 0.9)
			tw.tween_callback(func() -> void:
				spr.play(&"quieto")
				j.set_physics_process(true))
	_controlando = true
	_flecha.visible = true
	_saltear.text = "ESC: SALTEAR" if not DisplayServer.is_touchscreen_available() else ""
	if not Juego.dos_jugadores():
		_ayuda.text = "TOCA LANZA PARA ATACAR" if DisplayServer.is_touchscreen_available() else "J ATACA   K BLOQUEA   L RABIA"


func _process(delta: float) -> void:
	if _temblor > 0.0:
		_temblor = maxf(_temblor - delta, 0.0)
		camara.offset = (Vector2(randf_range(-2, 2), randf_range(-1, 1)) * (_temblor / 0.3)).round()
	else:
		camara.offset = Vector2.ZERO
	if _flecha.visible:
		_flecha.modulate.a = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 180.0))
	if not _controlando or _saliendo:
		return
	for j in _jugadores:
		# no se puede caminar "a través" del pedestal
		if j.position.y < 117.0 and j.position.x < 116.0 and j.position.x > 40.0:
			j.position.x = 116.0
		j.position.x = minf(j.position.x, 250.0)
		if j.position.x >= SALIDA_X:
			_ir_al_nivel()
			return


func _unhandled_input(event: InputEvent) -> void:
	if _saliendo:
		return
	var toque: bool = event is InputEventScreenTouch and event.pressed
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pausa") \
			or (not _controlando and (event.is_action_pressed("ui_accept") or toque)):
		_ir_al_nivel()


func _ir_al_nivel() -> void:
	if _saliendo:
		return
	_saliendo = true
	_controlando = false
	Musica.tocar("catedral", 0.8)
	_negro.color = Color(0, 0, 0, 0)
	var tw := create_tween()
	tw.tween_property(_negro, "color:a", 1.0, 0.5)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(ESCENA_NIVEL))


# ---------------------------------------------------------------- efectos
func _tween(obj: Object, prop: String, valor: Variant, dur: float) -> Signal:
	var tw := create_tween()
	tw.tween_property(obj, prop, valor, dur)
	return tw.finished


func _piedritas(donde: Vector2, cantidad: int) -> void:
	var p := CPUParticles2D.new()
	p.position = donde
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = cantidad
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14, 26)
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.78, 0.77, 0.7), Color(0.5, 0.49, 0.45)])
	p.color_initial_ramp = g
	p.z_index = 10
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _polvo(donde: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = donde
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 0.6
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 36.0
	p.gravity = Vector2(0, 60)
	p.damping_min = 10.0
	p.damping_max = 30.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#6a8a58"), Color("#3c5a40"), Color("#b8b0a0")])
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
