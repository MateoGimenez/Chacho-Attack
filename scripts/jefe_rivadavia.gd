extends "res://scripts/jefe.gd"
## RIVADAVIA — el luchador del dúo del Superdomo (nivel 2). Pelea junto a Rosas.
##  - Muy móvil: te persigue por toda la pantalla.
##  - BARRIDO con el sable largo: pega a los DOS lados, un poco más lejos que un soldado.
##  - CORRIDA EN DIAGONAL: brilla, se lanza en línea recta hacia donde estás (y se pasa de largo)
##    pegando al pasar, y remata con un barrido si quedó cerca.
##  - Si Rosas cae, se enoja: más rápido y ataca más seguido.

var _modo := "normal"     # normal · aviso · corrida
var _t := 0.0
var _prox_corrida := 3.0
var _dir := Vector2.RIGHT
var _ya: Array = []
var _fantasma_t := 0.0
var _enojado := false


func _physics_process(delta: float) -> void:
	aplicar_empuje(delta)
	if estado == Estado.MUERTO:
		return
	if limitar(delta):
		return
	if not _enojado and solo():
		_enojarse()
	_espera -= delta
	_prox_corrida -= delta
	match _modo:
		"aviso":
			_t -= delta
			if _t <= 0.0:
				_arrancar_corrida()
			return
		"corrida":
			_seguir_corrida(delta)
			return
	if estado != Estado.NORMAL:
		return
	var j := buscar_jugador(delta)
	if j == null:
		reproducir(&"quieto")
		return
	mirar_hacia(j.position.x > position.x)
	var d := j.position - position
	if _prox_corrida <= 0.0 and d.length() > 40.0:
		_preparar_corrida(j)
		return
	# lo persigue y se pone pegado al costado (si contra el borde no entra, del otro lado)
	var lado := -signf(d.x) if d.x != 0.0 else 1.0
	var x := j.position.x + lado * 19.0
	if x < izq() or x > der():
		lado = -lado
		x = j.position.x + lado * 19.0
	var hacia := Vector2(x, j.position.y) - position + _separacion()
	var al_alcance := absf(d.x) < 30.0 and absf(d.y) < 6.0
	if _espera <= 0.0 and al_alcance:
		reproducir(&"quieto")
		_atacar()
		sprite.speed_scale = 1.05 if not _enojado else 1.3
	elif hacia.length() > 2.5:
		position += hacia.normalized() * velocidad * delta
		reproducir(&"guardia")
	else:
		reproducir(&"quieto")


## El barrido del sable largo pega a los dos lados
func _golpe_cuerpo_a_cuerpo() -> void:
	mostrar_tajo(&"barrido", 30.0, 15.0, Color(1.0, 0.6, 0.5))
	Sonido.tocar("espadazo", -3.0)
	golpear(&"jugador", danio, 55.0, 30.0, 9.0, true)


func _preparar_corrida(j: Luchador) -> void:
	_modo = "aviso"
	_t = 0.35
	estado = Estado.ATAQUE
	reproducir(&"guardia")
	sprite.pause()
	_destello(Color(1.9, 1.5, 1.2))
	Sonido.tocar("aviso_enemigo", -6.0)
	# apunta a donde está el jugador y se pasa de largo un poco
	var objetivo := j.position + (j.position - position).normalized() * 30.0
	_dir = (objetivo - position).normalized()
	_ya.clear()


func _arrancar_corrida() -> void:
	_modo = "corrida"
	_t = 0.0
	mirar_hacia(_dir.x > 0.0)
	sprite.play(&"guardia")
	sprite.speed_scale = 2.0
	Sonido.tocar("esquiva")


func _seguir_corrida(delta: float) -> void:
	_t += delta
	var vel := 175.0 if not _enojado else 200.0
	position += Vector2(_dir.x, _dir.y * 0.7) * vel * delta
	_fantasma_t -= delta
	if _fantasma_t <= 0.0:
		_fantasma_t = 0.035
		fantasma(Color(1.0, 0.55, 0.5, 0.45))
	pegar_contacto(_ya, 10, 70.0, 12.0, 6.0)
	var fuera := position.x <= izq() or position.x >= der() \
		or position.y <= piso_arriba or position.y >= piso_abajo
	if _t > 0.6 or fuera:
		_modo = "normal"
		estado = Estado.NORMAL
		sprite.speed_scale = 1.0
		_prox_corrida = randf_range(3.0, 4.5) * (0.7 if _enojado else 1.0)
		# remate: barrido si quedó alguien cerca
		var j := _jugador_mas_cercano()
		if j != null and absf(j.position.x - position.x) < 32.0 and absf(j.position.y - position.y) < 9.0:
			_espera = 0.0
			_atacar()
			sprite.speed_scale = 1.3


func _enojarse() -> void:
	_enojado = true
	velocidad *= 1.3
	espera_min *= 0.6
	espera_max *= 0.6
	tinte = Color(1.25, 0.85, 0.85)
	sprite.self_modulate = tinte
	decir("¡RIVADAVIA SE ENOJA!", Color("#ff8a7a"))
