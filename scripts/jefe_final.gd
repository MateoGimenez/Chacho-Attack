extends "res://scripts/jefe.gd"
## EL TESORERO — jefe final de la Chaya (nivel 3): el hombre de traje con bigote que diseñó el equipo
## (personaje inventado), con sus agentes de custodia. Nombre: TIPOS de nivel.gd ("tesorero").
## Sprites: fuentes/gen_jefe_final.py → sprites/enemigos/tesorero_16px.png y agente_1/2/3_16px.png.
##
## FASE 1 — protegido por guardaespaldas
##  - Llega con 2 GUARDAESPALDAS. Mientras quede alguno vivo, a él no le entra nada (escudo dorado).
##  - Tira abanicos de BILLETES ("bonos") que vuelan como naipes: se esquivan caminando arriba/abajo.
##  - Cuando caen los guardaespaldas queda "SIN CUSTODIA" unos segundos y después llama a otros.
## FASE 2 — a la mitad de la vida se sube a la MAQUINA DE OBRA PUBLICA
##  - PALA: si estás adelante, levanta la pala y la baja. Pega fuerte.
##  - EMBESTIDA: marca su carril en rojo, acelera los motores y cruza la pantalla. Salí del carril.
##    Al llegar al borde queda trabada contra la pared un rato: los motores quedan a tu alcance.
##  - Solo le entran los golpes por ATRÁS (los motores). De frente: ¡CLANK!

const MECHA := preload("res://sprites/jefes/mecha.png")
const SIN_CUSTODIA := 8.0
const ANCHO_MECHA := 26.0

var fase_jefe := 1
var _modo := "normal"          # normal · cambio · aviso · embestida · trabado
var _guardias: Array[Luchador] = []
var _llamo := false
var _llamadas := 0
var _sin_custodia := 0.0
var _t := 0.0
var _flotar := 0.0
var _prox_embestida := 5.0
var _prox_billetes := 4.0
var _humo := 0.0
var _ya: Array = []
var _dir := 1.0
var _explico_motores := false
var _giro := 0.0   # la máquina tarda en darse vuelta: ponerse atrás es la estrategia
## En la embestida la máquina te pisa: no se bloquea (la pala sí)
var imparable := false


func _ready() -> void:
	super._ready()
	desaparecer_al_morir = false
	aguante = 7


func _process(delta: float) -> void:
	super._process(delta)
	_flotar += delta
	queue_redraw()


func _draw() -> void:
	if fase_jefe == 2:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2(-4, 0), 40.0, Color(0, 0, 0, 0.35))
		return
	super._draw()
	if _protegido() and estado != Estado.MUERTO:
		# escudo dorado de "custodia"
		draw_set_transform(Vector2.ZERO)
		var a := 0.35 + 0.2 * sin(_flotar * 6.0)
		draw_arc(Vector2(0, -19), 17.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, a), 1.0)
		draw_arc(Vector2(0, -19), 15.0, _flotar * 2.0, _flotar * 2.0 + 1.2, 6, Color(1, 1, 0.8, a + 0.2), 1.0)


func _protegido() -> bool:
	for g in _guardias:
		if is_instance_valid(g) and g.estado != Estado.MUERTO:
			return true
	return false


func _physics_process(delta: float) -> void:
	aplicar_empuje(delta)
	if estado == Estado.MUERTO:
		return
	if limitar(delta):
		return
	if not _llamo:
		_llamo = true
		_llamar_guardias()
	_espera -= delta
	if fase_jefe == 1:
		_fase_1(delta)
	else:
		_fase_2(delta)


# ================================================================ FASE 1

func _llamar_guardias() -> void:
	if _llamadas > 0:   # la primera vez ya lo dice la presentación ("Y SU CUSTODIA")
		nivel.mensaje("¡CUSTODIA!", "", 1.0)
	_llamadas += 1
	_guardias.clear()
	Sonido.tocar("billetes", 0.0, 0.0)
	for lado in [-1.0, 1.0]:
		var g: Luchador = nivel.aparecer("guardia", lado)
		if g != null:
			_guardias.append(g)
	_sin_custodia = 0.0


func _fase_1(delta: float) -> void:
	if _modo == "cambio":
		return
	# sin guardaespaldas: ventana para pegarle, después llama a otros
	if not _protegido():
		if _sin_custodia <= 0.0:
			_sin_custodia = SIN_CUSTODIA
			nivel.mensaje("¡SIN CUSTODIA!", "¡AHORA!", 1.0)
		_sin_custodia -= delta
		if _sin_custodia <= 0.01:
			_llamar_guardias()
	if estado != Estado.NORMAL:
		return
	var j := buscar_jugador(delta)
	if j == null:
		reproducir(&"quieto")
		return
	var dx := j.position.x - position.x
	mirar_hacia(dx > 0.0)
	# se queda a distancia de tiro, del lado donde está, y se acomoda en el carril del jugador
	var lado := -signf(dx) if dx != 0.0 else 1.0
	var destino := Vector2(j.position.x + lado * 64.0, j.position.y)
	destino.x = clampf(destino.x, izq() + 4.0, der() - 4.0)
	var hacia := destino - position + _separacion()
	if hacia.length() > 3.0:
		position += hacia.normalized() * velocidad * delta
		reproducir(&"caminar")
	else:
		reproducir(&"quieto")
	if _espera <= 0.0:
		_atacar()
		sprite.speed_scale = 1.0
		_espera = randf_range(espera_min, espera_max) * (0.7 if not _protegido() else 1.0)


func _al_cambiar_frame(anim: StringName, frame: int) -> void:
	if estado != Estado.ATAQUE or anim != &"ataque":
		return
	if fase_jefe == 1 and frame == EnemigoFrames.CUADRO_DISPARO:
		_abanico(7 if not _protegido() else 5, 0.5)
	elif fase_jefe == 2 and frame == 2:
		_bajar_pala()


## Abanico de billetes hacia donde mira
func _abanico(cantidad: int, apertura: float) -> void:
	Sonido.tocar("billetes", 0.0, 0.0)
	var dir := 1.0 if mira_derecha else -1.0
	var salida := position + Vector2(dir * (14.0 if fase_jefe == 1 else 20.0), 0)
	for i in cantidad:
		var k := (float(i) / maxf(cantidad - 1, 1)) * 2.0 - 1.0   # -1 .. 1
		var b := AtaquesJefes.Billete.new()
		b.position = salida
		b.velocidad = Vector2(dir * 112.0, k * apertura * 55.0)
		b.color = i % 3
		b.altura = 20.0 if fase_jefe == 1 else 30.0
		nivel.mundo.add_child(b)


# ================================================================ daño y cambio de fase

func recibir_golpe(danio_: int, atacante: Node2D, fuerza: float) -> bool:
	if estado == Estado.MUERTO or _modo == "cambio" or _entrando:
		return false
	var es_jugador := atacante.is_in_group("jugador")
	if fase_jefe == 1:
		if _protegido():
			_destello(Color(2.2, 1.9, 0.8))
			Sonido.tocar("escudo")
			decir("¡PROTEGIDO!", Color("#ffe066"))
			return false
		var entro := super.recibir_golpe(danio_, atacante, fuerza)
		if entro and vida <= vida_max / 2 and vida > 0:
			_empezar_cambio.call_deferred()
		return entro
	# FASE 2: la máquina. De frente rebota; por atrás (los motores) entra con todo.
	if es_jugador and de_frente(atacante):
		_destello(Color(1.6, 1.6, 1.8))
		Sonido.tocar("clank")
		nivel.chispas(global_position + Vector2((8.0 if mira_derecha else -8.0) + 20.0 * (1.0 if mira_derecha else -1.0), -16),
			[Color.WHITE, Color("#ffe9a0"), Color("#c0c4cc")], 6)
		decir("¡CLANK!" if _explico_motores else "¡PEGALE A LOS MOTORES!", Color("#c0c4cc"))
		return false
	var d := int(danio_ * 1.3)
	vida = maxi(vida - d, 0)
	vida_cambio.emit(vida, vida_max)
	_destello(Color(2.4, 1.6, 1.0))
	aplastar(Vector2(1.06, 0.95))
	Sonido.tocar("golpe_fuerte" if fuerza >= GOLPE_FUERTE else "golpe")
	impacto.emit(global_position + Vector2(-16.0 if mira_derecha else 16.0, 0), fuerza >= GOLPE_FUERTE)
	var motor := global_position + Vector2(-34.0 if mira_derecha else 34.0, -26)
	nivel.chispas(motor, [Color("#ffb347"), Color("#ff6a2a"), Color("#3a3036")], 8)
	if vida <= 0:
		morir()
	return true


func _empezar_cambio() -> void:
	if _modo == "cambio" or fase_jefe == 2 or estado == Estado.MUERTO:
		return
	_modo = "cambio"
	estado = Estado.NORMAL
	reproducir(&"quieto")
	# los guardaespaldas que quedan salen corriendo
	for g in _guardias:
		if is_instance_valid(g) and g.estado != Estado.MUERTO:
			g.morir()
	for n in get_tree().get_nodes_in_group("proyectiles"):
		n.queue_free()
	nivel.mensaje("¡A LA MAQUINA!", "DE OBRA PUBLICA", 1.8)
	Sonido.tocar("motor", 0.0, 0.0)
	# entra la máquina desde el borde más lejano y se pone donde está él
	var desde_der := position.x < (izq() + der()) / 2.0
	var maquina := Sprite2D.new()
	maquina.texture = MECHA
	maquina.region_enabled = true
	maquina.region_rect = Rect2(0, 72, 96, 72)
	maquina.offset = Vector2(0, -33)
	maquina.flip_h = desde_der
	maquina.position = Vector2(nivel.limites().y + 50.0 if desde_der else nivel.limites().x - 50.0, position.y + 0.1)
	nivel.mundo.add_child(maquina)
	var tw := create_tween()
	tw.tween_property(maquina, "position:x", position.x, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(k: float) -> void:
		maquina.region_rect = Rect2(96 * (int(k * 20.0) % 4), 72, 96, 72), 0.0, 1.0, 1.5)
	# él salta adentro de la cabina
	tw.tween_property(sprite, "position:y", -30.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func() -> void:
		maquina.queue_free()
		_subirse(desde_der))


func _subirse(desde_der: bool) -> void:
	fase_jefe = 2
	_modo = "normal"
	sprite.sprite_frames = _frames_mecha()
	sprite.offset = Vector2(0, -33)
	sprite.position = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE
	tinte = Color.WHITE
	sprite.play(&"quieto")
	mirar_hacia(not desde_der)
	ancho = ANCHO_MECHA
	velocidad = 15.0
	super_armadura = true
	aguante = 99   # la máquina no se "sacude"
	_espera = 1.0
	_prox_embestida = 3.5
	Sonido.tocar("golpe_fuerte")
	nivel.temblar(0.4)
	nivel.polvo(position, 2.0)


func _frames_mecha() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	# nombre: [fila, primer cuadro, cuántos, cuadros por segundo, se repite, duraciones]
	var anims := {
		"quieto": [0, 0, 2, 3.0, true, {}],
		"caminar": [1, 0, 4, 10.0, true, {}],
		"guardia": [1, 0, 4, 14.0, true, {}],
		"ataque": [2, 0, 4, 8.0, false, {0: 3.0, 1: 1.5, 2: 2.0}],
		"dolor": [3, 0, 1, 6.0, false, {}],
		"muerte": [3, 1, 1, 6.0, false, {}],
	}
	for nombre: String in anims:
		var d: Array = anims[nombre]
		sf.add_animation(nombre)
		sf.set_animation_speed(nombre, d[3])
		sf.set_animation_loop(nombre, d[4])
		for i in d[2]:
			var at := AtlasTexture.new()
			at.atlas = MECHA
			at.region = Rect2((d[1] + i) * 96, d[0] * 72, 96, 72)
			sf.add_frame(nombre, at, (d[5] as Dictionary).get(i, 1.0))
	return sf


# ================================================================ FASE 2

func _fase_2(delta: float) -> void:
	position.x = clampf(position.x, izq() + 18.0, der() - 18.0)   # es ancha: que no se salga
	imparable = _modo == "embestida"
	_humo -= delta
	if _humo <= 0.0:
		# humo de los motores: más negro y seguido cuanto más rota está
		var roto := 1.0 - float(vida) / (vida_max / 2.0)
		_humo = lerpf(0.5, 0.12, clampf(roto, 0.0, 1.0))
		var atras := -1.0 if mira_derecha else 1.0
		nivel.chispas(global_position + Vector2(atras * 38.0, -58), [Color(0.3, 0.3, 0.32, 0.8), Color(0.15, 0.15, 0.17, 0.8)], 3)
	match _modo:
		"aviso":
			_t -= delta
			reproducir(&"guardia")
			if _t <= 0.0:
				_modo = "embestida"
				Sonido.tocar("pala", 0.0, 0.0)
			return
		"embestida":
			position.x += _dir * 190.0 * delta
			reproducir(&"guardia")
			nivel.polvo(position + Vector2(-_dir * 30.0, 0), 0.6)
			var frente := position.x + _dir * 20.0
			var yo_y := position.y
			var cond := func(p: Luchador) -> bool:
				return absf(p.position.y - yo_y) < 12.0 and absf(p.position.x - frente) < 26.0
			if AtaquesJefes.pegar(get_tree(), self, _ya, 18, 140.0, cond) > 0:
				nivel.temblar(0.3)
			if position.x <= izq() + 18.0 or position.x >= der() - 18.0:
				_modo = "trabado"
				_t = 3.6
				Sonido.tocar("clank", 0.0, 0.0)
				nivel.temblar(0.5)
				nivel.polvo(position + Vector2(_dir * 36.0, 0), 2.0)
				reproducir(&"dolor")
				if not _explico_motores:
					_explico_motores = true
					nivel.mensaje("¡SE TRABO!", "¡PEGALE A LOS MOTORES!", 1.4)
			return
		"trabado":
			_t -= delta
			if _t <= 0.0:
				_modo = "normal"
				_prox_embestida = randf_range(5.5, 7.0)
			return
	if estado != Estado.NORMAL:
		return
	_prox_embestida -= delta
	_prox_billetes -= delta
	var j := buscar_jugador(delta)
	if j == null:
		reproducir(&"quieto")
		return
	var dx := j.position.x - position.x
	var dy := j.position.y - position.y
	# si el jugador se le pone atrás, tarda 1,1 s en girar (le entran los golpes a los motores)
	if (dx > 0.0) != mira_derecha:
		_giro += delta
		if _giro > 1.1:
			_giro = 0.0
			mirar_hacia(dx > 0.0)
			Sonido.tocar("motor", -8.0)
			nivel.polvo(position, 1.0)
		reproducir(&"quieto")
		return
	_giro = 0.0
	if _prox_embestida <= 0.0:
		_preparar_embestida()
		return
	if _prox_billetes <= 0.0 and absf(dx) > 80.0:
		_prox_billetes = randf_range(3.5, 5.0)
		_abanico(3, 0.35)
	# se acerca hasta tener al jugador al alcance de la pala, y se acomoda en su carril
	var quiere := Vector2(j.position.x - signf(dx) * 44.0, j.position.y)
	var hacia := quiere - position
	if hacia.length() > 3.0:
		position += Vector2(hacia.x, hacia.y * 0.6).normalized() * velocidad * delta
		reproducir(&"caminar")
	else:
		reproducir(&"quieto")
	if _espera <= 0.0 and absf(dx) < 56.0 and absf(dy) < 12.0:
		estado = Estado.ATAQUE
		reiniciar(&"ataque")
		_destello(Color(1.8, 1.5, 1.1))
		Sonido.tocar("motor", -6.0)
		_espera = randf_range(1.6, 2.3)


func _bajar_pala() -> void:
	Sonido.tocar("pala")
	nivel.temblar(0.25)
	var dir := 1.0 if mira_derecha else -1.0
	nivel.polvo(position + Vector2(dir * 44.0, 0), 1.6)
	golpear(&"jugador", 16, 110.0, 52.0, 12.0)


func _preparar_embestida() -> void:
	_modo = "aviso"
	_t = 1.1
	_ya.clear()
	# apunta al jugador (si está pegado a la pared de ese lado, embiste para el otro)
	var j := _jugador_mas_cercano()
	_dir = 1.0 if j == null or j.position.x > position.x else -1.0
	if (_dir > 0.0 and der() - position.x < 70.0) or (_dir < 0.0 and position.x - izq() < 70.0):
		_dir = -_dir
	mirar_hacia(_dir > 0.0)
	_giro = 0.0
	Sonido.tocar("motor", 0.0, 0.0)
	_destello(Color(2.0, 1.4, 1.0))
	var lim: Vector2 = nivel.limites()
	var f := AtaquesJefes.Franja.new()
	f.y0 = position.y - 12.0
	f.y1 = position.y + 12.0
	f.izq = lim.x
	f.der = lim.y
	f.direccion = _dir
	f.duracion = 1.1 + 0.6
	nivel.avisos.add_child(f)


func morir() -> void:
	super.morir()
	if fase_jefe != 2:
		return
	# la máquina explota en partes
	for i in 5:
		get_tree().create_timer(0.18 * i, true, false, true).timeout.connect(func() -> void:
			Sonido.tocar("explosion")
			var p := global_position + Vector2(randf_range(-34, 34), randf_range(-50, -8))
			nivel.chispas(p, [Color.WHITE, Color("#ffe066"), Color("#ff8a2a"), Color("#3a3036")], 16)
			nivel.temblar(0.3))
