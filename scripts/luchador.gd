class_name Luchador
extends Node2D
## Base común para el Chacho y los enemigos: vida, golpes, dolor y muerte.
##
## Cómo funciona un beat 'em up "2.5D":
##  - X = izquierda/derecha.  Y = profundidad (más abajo en pantalla = más cerca).
##  - Un golpe acierta si el enemigo está delante, dentro del largo de la lanza
##    (alcance) Y a una profundidad parecida (profundidad). No usamos física.

signal vida_cambio(vida: int, vida_max: int)
signal murio(quien: Luchador)
## Pisada (para levantar polvo según el piso del escenario)
signal paso(donde: Vector2, corriendo: bool)
## Recibió un golpe que entró (para efectos de impacto)
signal impacto(donde: Vector2, fuerte: bool)

enum Estado { NORMAL, ATAQUE, BLOQUEO, DOLOR, MUERTO }

## Un golpe con esta fuerza (o más) es "fuerte": hace volar y atraviesa la súper armadura
const GOLPE_FUERTE := 75.0

## Franja del piso por donde se puede caminar (en píxeles de pantalla).
## Cada nivel la cambia según dónde empieza el piso en su imagen de fondo.
static var piso_arriba := 93.0
static var piso_abajo := 131.0

@export var vida_max := 100
@export var velocidad := 37.5
## Si es true, los golpes débiles no lo frenan (sirve para jefes)
@export var super_armadura := false
## Segundos de invulnerabilidad después de recibir un golpe
@export var tiempo_invulnerable := 0.0
## Si es true, sale volando un poco con los golpes fuertes y al morir
@export var puede_volar := true
## Medio ancho extra del cuerpo para los golpes (0 = una persona; la máquina del jefe final es ancha)
@export var ancho := 0.0

var vida := 0
var estado := Estado.NORMAL
var mira_derecha := true
var empuje := 0.0  # retroceso horizontal cuando te pegan
var _invulnerable_hasta := 0
var _tween_salto: Tween
var _tween_squash: Tween

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	vida = vida_max
	sprite.animation_finished.connect(func() -> void: _fin_animacion(sprite.animation))
	sprite.frame_changed.connect(func() -> void: _al_cambiar_frame(sprite.animation, sprite.frame))
	sprite.frame_changed.connect(_revisar_pisada)
	sprite.play(&"quieto")


func _draw() -> void:
	# Sombra en los pies (se dibuja debajo del sprite)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35))


func _process(_delta: float) -> void:
	# Parpadeo mientras es invulnerable
	if esta_invulnerable() and estado != Estado.MUERTO:
		sprite.visible = (Time.get_ticks_msec() / 60) % 2 == 0
	else:
		sprite.visible = true


# ---------- Ayudas para hijos ----------

func mirar_hacia(derecha: bool) -> void:
	mira_derecha = derecha
	sprite.flip_h = not derecha


## Cambia de animación solo si es distinta (para caminar, quieto, etc.)
func reproducir(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


## Arranca una animación desde el principio (para ataques)
func reiniciar(anim: StringName) -> void:
	sprite.stop()
	sprite.play(anim)


func esta_invulnerable() -> bool:
	return Time.get_ticks_msec() < _invulnerable_hasta


func hacer_invulnerable(segundos: float) -> void:
	_invulnerable_hasta = Time.get_ticks_msec() + int(segundos * 1000.0)


func aplicar_empuje(delta: float) -> void:
	if empuje != 0.0:
		position.x += empuje * delta
		empuje = move_toward(empuje, 0.0, 350.0 * delta)
	position.y = clampf(position.y, piso_arriba, piso_abajo)


## Golpea a todos los del grupo que estén al alcance. Devuelve cuántos acertó.
func golpear(grupo: StringName, danio: int, fuerza: float, alcance: float,
		profundidad: float, ambos_lados := false) -> int:
	var acertados := 0
	for nodo in get_tree().get_nodes_in_group(grupo):
		var otro := nodo as Luchador
		if otro == null or otro.estado == Estado.MUERTO:
			continue
		var dx := (otro.global_position.x - global_position.x) / scale.x
		var dy := absf(otro.global_position.y - global_position.y)
		if dy > profundidad:
			continue
		var delante := absf(dx) if ambos_lados else (dx if mira_derecha else -dx)
		if delante < -5.0 - otro.ancho or delante > alcance + otro.ancho:
			continue
		if otro.recibir_golpe(danio, self, fuerza):
			acertados += 1
	return acertados


## Devuelve true si el golpe entró (false si era invulnerable)
func recibir_golpe(danio: int, atacante: Node2D, fuerza: float) -> bool:
	if estado == Estado.MUERTO or esta_invulnerable():
		return false
	var viene_de_derecha := atacante.global_position.x > global_position.x
	# Lo que cae de arriba o te pisa (libros, caballería, la máquina) no se puede bloquear:
	# esos ataques tienen la variable "imparable" en true.
	var bloqueado: bool = estado == Estado.BLOQUEO and viene_de_derecha == mira_derecha \
		and atacante.get("imparable") != true

	if bloqueado:
		danio = int(danio * 0.2)
		fuerza *= 0.3
		_destello(Color(0.7, 0.9, 1.6))
		Sonido.tocar("bloqueo")
	elif super_armadura and fuerza < GOLPE_FUERTE:
		_destello(Color(2.2, 2.2, 2.2))
	else:
		estado = Estado.DOLOR
		sprite.speed_scale = 1.0
		reiniciar(&"dolor")
		_destello(Color(2.5, 2.5, 2.5))
		if tiempo_invulnerable > 0.0:
			hacer_invulnerable(tiempo_invulnerable)

	if not bloqueado:
		Sonido.tocar(_sonido_impacto(fuerza))
		impacto.emit(global_position, fuerza >= GOLPE_FUERTE)
		aplastar(Vector2(1.18, 0.86))
		if fuerza >= GOLPE_FUERTE and puede_volar:
			saltito(7.0)
	vida = maxi(vida - danio, 0)
	vida_cambio.emit(vida, vida_max)
	empuje = -fuerza if viene_de_derecha else fuerza
	if vida <= 0:
		morir()
	return true


func morir() -> void:
	estado = Estado.MUERTO
	var s := _sonido_muerte()
	if s != "":
		Sonido.tocar(s)
	sprite.speed_scale = 1.0
	reiniciar(&"muerte")
	empuje *= 1.5
	if puede_volar:
		saltito(10.0)
	murio.emit(self)


# ---------- Animaciones extra (por código) ----------

## "Squash & stretch": se aplasta y vuelve. Da sensación de peso al golpe.
func aplastar(escala: Vector2) -> void:
	if _tween_squash:
		_tween_squash.kill()
	sprite.scale = escala
	_tween_squash = create_tween()
	_tween_squash.tween_property(sprite, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Salto corto hacia arriba (cuando lo revientan de un golpe o muere)
func saltito(alto: float) -> void:
	if _tween_salto:
		_tween_salto.kill()
	_tween_salto = create_tween()
	_tween_salto.tween_property(sprite, "position:y", -alto, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_salto.tween_property(sprite, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Estela de la lanza. tipo: &"estocada" (línea recta) o &"barrido" (arco alrededor)
func mostrar_tajo(tipo: StringName, largo: float, altura: float, color: Color) -> void:
	var t := Tajo.new()
	t.tipo = tipo
	t.largo = largo
	t.color = color
	t.direccion = 1.0 if mira_derecha else -1.0
	t.position = Vector2(0, -altura)
	add_child(t)


## Copia "fantasma" del cuadro actual que se desvanece (para movimientos rápidos)
func fantasma(color: Color, duracion := 0.25) -> void:
	var g := Sprite2D.new()
	g.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	g.flip_h = sprite.flip_h
	g.offset = sprite.offset + Vector2(0, 0.1)
	g.global_position = sprite.global_position + Vector2(0, -0.1)
	g.scale = global_scale * sprite.scale
	g.modulate = color
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, duracion)
	tw.tween_callback(g.queue_free)


func _revisar_pisada() -> void:
	var anim := sprite.animation
	if (anim == &"caminar" or anim == &"correr") and (sprite.frame == 1 or sprite.frame == 4):
		paso.emit(global_position, anim == &"correr")


func _destello(color: Color) -> void:
	sprite.modulate = color
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, 0.15)


# ---------- Para que los hijos sobrescriban ----------

func _al_cambiar_frame(_anim: StringName, _frame: int) -> void:
	pass


## Qué sonido hace al recibir un golpe (los hijos lo cambian: barril = madera, Chacho = queja)
func _sonido_impacto(fuerza: float) -> String:
	return "golpe_fuerte" if fuerza >= GOLPE_FUERTE else "golpe"


## Qué sonido hace al morir ("" = ninguno)
func _sonido_muerte() -> String:
	return ""


func _fin_animacion(_anim: StringName) -> void:
	if estado == Estado.DOLOR or estado == Estado.ATAQUE:
		estado = Estado.NORMAL
		sprite.speed_scale = 1.0


## Dibuja la estela de la lanza y se borra sola en un instante
class Tajo extends Node2D:
	const DURACION := 0.14
	var tipo := &"estocada"
	var largo := 25.0
	var color := Color.WHITE
	var direccion := 1.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= DURACION:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - _t / DURACION
		var avance := minf(_t / (DURACION * 0.35), 1.0)  # crece rápido y después se apaga
		if tipo == &"barrido":
			var puntos := PackedVector2Array()
			var colores := PackedColorArray()
			var pasos := 18
			for i in pasos + 1:
				var ang := lerpf(-0.9, PI + 0.9, float(i) / pasos * avance)
				puntos.append(Vector2(cos(ang) * largo * 0.85 * direccion, sin(ang) * 5.5 + 3.0))
				colores.append(Color(color, a * float(i) / pasos))
			draw_polyline_colors(puntos, colores, 2.0)
		else:
			var punta := largo * avance * direccion
			var cuerpo := 7.0 * direccion
			draw_colored_polygon(PackedVector2Array([Vector2(cuerpo, -1.5), Vector2(punta, 0), Vector2(cuerpo, 1.5)]),
				Color(color, a * 0.55))
			draw_line(Vector2(cuerpo, 0), Vector2(punta, 0), Color(1, 1, 1, a), 1.0)
