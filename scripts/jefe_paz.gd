extends "res://scripts/jefe.gd"
## GRAL. JOSE MARIA PAZ, "EL MANCO" — jefe de la Catedral (nivel 1).
## Jefe "táctico" al estilo de Sega:
##  - Camina despacio y con elegancia. ESQUIVA casi todo lo que le tirás DE FRENTE (paso al costado).
##    Le entra todo: por la espalda, mientras ataca y un ratito después de atacar ("recuperando").
##  - Estocadas rápidas con el sable (2 por ataque, a veces encadena otro).
##  - Embestida: si estás lejos en su mismo carril, brilla y se lanza hacia adelante.
##  - SILBIDO: llama a la caballería. Se marca una franja roja del piso y después cruza la carga.
##    Hay que salir de la franja (subir o bajar). No se bloquea. Por debajo de media vida, 2 cargas.
##    Mientras silba no esquiva: es buen momento para pegarle... si te da el tiempo.

const PROB_ESQUIVA := 0.75
const CADA_SILBIDO := 12.0
const ALTO_FRANJA := 17.0

var _modo := "normal"       # normal · embestida · silbido
var _recupera := 0.0        # mientras sea > 0 no esquiva
var _esquivando := 0.0
var _prox_silbido := 7.0
var _prox_embestida := 4.0
var _seguidas := 0          # estocadas que le quedan por encadenar
var _embestida_t := 0.0
var _embestida_dir := 1.0
var _ya: Array = []
var _fantasma_t := 0.0


func _physics_process(delta: float) -> void:
	aplicar_empuje(delta)
	if estado == Estado.MUERTO:
		return
	if limitar(delta):
		return
	_recupera -= delta
	_esquivando -= delta
	_prox_silbido -= delta
	_prox_embestida -= delta
	_espera -= delta
	match _modo:
		"embestida":
			_seguir_embestida(delta)
			return
		"silbido":
			return
	if estado != Estado.NORMAL:
		return
	var j := buscar_jugador(delta)
	if j == null:
		reproducir(&"quieto")
		return
	mirar_hacia(j.position.x > position.x)
	var dx := j.position.x - position.x
	var dy := j.position.y - position.y

	if _prox_silbido <= 0.0:
		_silbar()
		return
	if _prox_embestida <= 0.0 and absf(dx) > 48.0 and absf(dx) < 115.0 and absf(dy) < 7.0:
		_preparar_embestida()
		return

	# se pone a su costado, a distancia de estocada, sin apuro.
	# Si contra el borde no entra de ese lado, lo rodea y se pone del otro.
	var lado := -signf(dx) if dx != 0.0 else 1.0
	var x := j.position.x + lado * 22.0
	if x < izq() or x > der():
		lado = -lado
		x = j.position.x + lado * 22.0
	var hacia := Vector2(x, j.position.y) - position
	var al_alcance := absf(dx) > 8.0 and absf(dx) < 28.0 and absf(dy) < 5.0
	if _espera <= 0.0 and al_alcance:
		reproducir(&"quieto")
		_seguidas = 1 if randf() < 0.45 else 0
		_estocadas()
	elif hacia.length() > 2.5:
		position += hacia.normalized() * velocidad * delta
		reproducir(&"caminar")
	else:
		reproducir(&"quieto")


func _estocadas() -> void:
	_atacar()
	sprite.speed_scale = 1.35   # rápido: es esgrimista
	_lado = 1.0


func _al_cambiar_frame(anim: StringName, frame: int) -> void:
	if _modo == "normal":   # en la embestida el golpe lo da pegar_contacto()
		super._al_cambiar_frame(anim, frame)


func _fin_animacion(anim: StringName) -> void:
	super._fin_animacion(anim)
	if anim == &"ataque":
		if _seguidas > 0 and _modo == "normal" and estado == Estado.NORMAL:
			_seguidas -= 1
			_estocadas()
			return
		_recupera = 0.55   # ventana para castigarlo


# ---------- esquive ----------

func recibir_golpe(danio_: int, atacante: Node2D, fuerza: float) -> bool:
	if _esquivando > 0.0:
		return false
	var puede := estado == Estado.NORMAL and _modo == "normal" and _recupera <= 0.0 and not _entrando
	if puede and atacante.is_in_group("jugador") and de_frente(atacante) and randf() < PROB_ESQUIVA:
		_esquivar()
		return false
	return super.recibir_golpe(danio_, atacante, fuerza)


func _esquivar() -> void:
	_esquivando = 0.3
	Sonido.tocar("esquiva")
	decir("¡ESQUIVA!", Color("#9fd8ff"))
	# paso al costado (hacia donde haya lugar) dejando fantasmas
	var arriba := position.y - piso_arriba > piso_abajo - position.y
	var destino := position.y + (-13.0 if arriba else 13.0)
	var tw := create_tween()
	tw.tween_property(self, "position:y", clampf(destino, piso_arriba, piso_abajo), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in 3:
		get_tree().create_timer(0.04 * i).timeout.connect(fantasma.bind(Color(0.6, 0.85, 1.0, 0.5)))
	# a veces contraataca enseguida
	if randf() < 0.35:
		_espera = 0.0
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			if estado == Estado.NORMAL and _modo == "normal":
				_seguidas = 0
				_estocadas())


# ---------- embestida ----------

func _preparar_embestida() -> void:
	_modo = "embestida"
	_embestida_t = -0.4   # 0,4 s de aviso
	_embestida_dir = 1.0 if mira_derecha else -1.0
	_ya.clear()
	estado = Estado.ATAQUE
	reproducir(&"guardia")
	sprite.pause()
	_destello(Color(1.9, 1.6, 1.1))
	Sonido.tocar("aviso_enemigo", -6.0)


func _seguir_embestida(delta: float) -> void:
	_embestida_t += delta
	if _embestida_t < 0.0:
		return
	if sprite.animation != &"ataque":
		sprite.play(&"ataque")
		sprite.pause()
		sprite.frame = 1
		Sonido.tocar("espadazo")
		mostrar_tajo(&"estocada", 30.0, 16.0, Color(0.7, 0.9, 1.0))
	position.x += _embestida_dir * 200.0 * delta
	_fantasma_t -= delta
	if _fantasma_t <= 0.0:
		_fantasma_t = 0.04
		fantasma(Color(0.6, 0.85, 1.0, 0.45))
	pegar_contacto(_ya, 12, 85.0, 14.0, 6.0)
	var choca := position.x <= izq() + 1.0 or position.x >= der() - 1.0
	if _embestida_t > 0.5 or choca:
		_modo = "normal"
		estado = Estado.NORMAL
		sprite.play(&"quieto")
		_recupera = 1.0
		_prox_embestida = randf_range(4.5, 6.5)


# ---------- silbido + caballería ----------

func _silbar() -> void:
	_modo = "silbido"
	_recupera = 9.0   # mientras silba no esquiva
	reproducir(&"quieto")
	_destello(Color(1.6, 1.6, 2.2))
	aplastar(Vector2(0.9, 1.12))
	Sonido.tocar("silbido", 0.0, 0.0)
	decir("¡FIUUU!", Color("#ffe066"))
	nivel.mensaje("¡CABALLERIA!", "", 1.0)
	var cargas := 2 if vida < vida_max / 2 else 1
	for i in cargas:
		get_tree().create_timer(0.5 + i * 1.9).timeout.connect(_lanzar_carga)
	get_tree().create_timer(0.5 + cargas * 1.9 + 0.6).timeout.connect(func() -> void:
		if estado != Estado.MUERTO:
			_modo = "normal"
			_recupera = 0.0
			_prox_silbido = CADA_SILBIDO * randf_range(0.85, 1.15))


func _lanzar_carga() -> void:
	if estado == Estado.MUERTO or not is_inside_tree():
		return
	# la franja tapa el carril del jugador más cercano (a veces corrida, para que no sea siempre igual)
	var j := _jugador_mas_cercano()
	var centro := position.y if j == null else j.position.y + randf_range(-5.0, 5.0)
	var y0 := clampf(centro - ALTO_FRANJA / 2.0, piso_arriba - 2.0, piso_abajo + 2.0 - ALTO_FRANJA)
	var e := AtaquesJefes.Estampida.new()
	e.nivel = nivel
	e.y0 = y0
	e.y1 = y0 + ALTO_FRANJA
	e.direccion = 1.0 if randf() < 0.5 else -1.0
	nivel.mundo.add_child(e)
	# Paz se corre de la franja (no lo pisan los suyos)
	if position.y > e.y0 - 4.0 and position.y < e.y1 + 4.0:
		var y_libre := e.y0 - 6.0 if e.y0 - piso_arriba > piso_abajo - e.y1 else e.y1 + 6.0
		var tw := create_tween()
		tw.tween_property(self, "position:y", clampf(y_libre, piso_arriba, piso_abajo), 0.6)
		reproducir(&"caminar")
