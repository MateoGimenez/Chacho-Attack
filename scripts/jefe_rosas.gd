extends "res://scripts/jefe.gd"
## ROSAS — el de la retaguardia en el dúo del Superdomo (nivel 2). Pelea junto a Rivadavia.
##  - Se queda lejos: busca el borde de la pantalla del lado contrario al jugador.
##  - TINTERO: lo tira en arco a donde estás; la sombra marca dónde cae.
##  - LIBROS: caen del cielo (1 a 3) sobre los jugadores. La sombra crece antes del golpe. No se bloquean.
##  - MEGAFONO: si estás en su carril, grita y sale una onda. Si te agarra sin bloquear, te ATURDE
##    (caminás muy lento un rato). Bloqueando de frente a la onda no te pasa nada.
##  - Si te le acercás, te empuja con un golpe y se escapa.
##  - Si Rivadavia cae, se enoja: tira más cosas y más seguido.

var _ataque := ""        # qué está tirando en esta animación
var _prox_lugar := 0.0
var _lugar := Vector2.ZERO
var _enojado := false


func _ready() -> void:
	super._ready()
	_espera = 2.2


func _physics_process(delta: float) -> void:
	aplicar_empuje(delta)
	if estado == Estado.MUERTO:
		return
	if limitar(delta):
		return
	if not _enojado and solo():
		_enojado = true
		espera_min *= 0.6
		espera_max *= 0.6
		tinte = Color(1.25, 0.85, 0.85)
		sprite.self_modulate = tinte
		decir("¡ROSAS SE ENOJA!", Color("#ff8a7a"))
	_espera -= delta
	_prox_lugar -= delta
	if estado != Estado.NORMAL:
		return
	var j := buscar_jugador(delta)
	if j == null:
		reproducir(&"quieto")
		return
	var d := j.position - position

	# Si lo apuran de cerca: empujón y a escaparse
	if absf(d.x) < 22.0 and absf(d.y) < 6.0 and _espera <= 0.6:
		mirar_hacia(d.x > 0.0)
		_tirar("empujon")
		return

	# Busca un lugar lejos: el borde contrario al jugador, a otra altura
	if _prox_lugar <= 0.0:
		_prox_lugar = randf_range(1.8, 2.8)
		var centro: float = (izq() + der()) / 2.0
		var x := der() - 6.0 if j.position.x < centro else izq() + 6.0
		_lugar = Vector2(x, randf_range(piso_arriba + 2.0, piso_abajo - 2.0))
	var hacia := _lugar - position + _separacion()
	var cerca := absf(d.x) < 45.0
	if hacia.length() > 3.0:
		position += hacia.normalized() * velocidad * (1.5 if cerca else 1.0) * delta
		reproducir(&"caminar")
		mirar_hacia(hacia.x > 0.0 if cerca else d.x > 0.0)
	else:
		reproducir(&"quieto")
		mirar_hacia(d.x > 0.0)

	if _espera <= 0.0:
		mirar_hacia(d.x > 0.0)
		var r := randf()
		if cerca:
			# acorralado: grita en la cara o le tira libros encima
			if absf(d.y) < 12.0 and r < 0.55:
				_tirar("megafono")
			else:
				_tirar("libros")
		elif absf(d.y) < 12.0 and r < 0.35:
			_tirar("megafono")
		elif r < 0.65:
			_tirar("libros")
		else:
			_tirar("tintero")


func _tirar(cual: String) -> void:
	_ataque = cual
	estado = Estado.ATAQUE
	reiniciar(&"ataque")
	_espera = randf_range(espera_min, espera_max)
	if cual == "megafono":
		sprite.speed_scale = 0.6   # el grito se ve venir
		_destello(Color(2.0, 1.8, 1.0))
		decir("¡SALVAJES UNITARIOS!", Color("#ff6a5a"))
	elif cual == "empujon":
		sprite.speed_scale = 1.2
		_espera = 1.4
		_prox_lugar = 0.0
	else:
		sprite.speed_scale = 1.0


func _al_cambiar_frame(anim: StringName, frame: int) -> void:
	if estado != Estado.ATAQUE or anim != &"ataque" or frame != EnemigoFrames.CUADRO_GOLPE:
		return
	var dir := 1.0 if mira_derecha else -1.0
	if _ataque != "megafono" and _ataque != "empujon" and _objetivos(1).is_empty():
		return
	match _ataque:
		"empujon":
			mostrar_tajo(&"estocada", 22.0, 16.0, Color(1.0, 0.55, 0.45))
			Sonido.tocar("culatazo")
			golpear(&"jugador", danio, 95.0, 24.0, 7.0)
		"tintero":
			for j in _objetivos(2 if _enojado else 1):
				var t := AtaquesJefes.Tintero.new()
				t.nivel = nivel
				t.desde = position + Vector2(dir * 8.0, 0)
				# apunta un poquito adelante de donde camina el jugador
				t.hasta = Vector2(clampf(j.position.x + randf_range(-6, 6), izq(), der()),
					clampf(j.position.y + randf_range(-3, 3), piso_arriba, piso_abajo))
				nivel.mundo.add_child(t)
		"libros":
			Sonido.tocar("lanzar")
			var cantidad := 3 if _enojado else 2
			var objetivos := _objetivos(cantidad)
			for i in cantidad:
				var j: Luchador = objetivos[i % objetivos.size()]
				var l := AtaquesJefes.Libro.new()
				l.nivel = nivel
				var corrido := Vector2.ZERO if i < objetivos.size() else Vector2(randf_range(-26, 26), randf_range(-10, 10))
				l.position = Vector2(clampf(j.position.x + corrido.x, izq(), der()),
					clampf(j.position.y + corrido.y, piso_arriba, piso_abajo))
				l.aviso = 0.95 + i * 0.3
				nivel.mundo.add_child(l)
		"megafono":
			Sonido.tocar("megafono", 0.0, 0.0)
			nivel.temblar(0.15)
			var o := AtaquesJefes.Onda.new()
			o.direccion = dir
			o.position = position + Vector2(dir * 10.0, 0)
			nivel.mundo.add_child(o)


## Los jugadores vivos (para repartir los ataques)
func _objetivos(cuantos: int) -> Array:
	var lista := []
	for n in get_tree().get_nodes_in_group("jugador"):
		if (n as Luchador).estado != Estado.MUERTO:
			lista.append(n)
	lista.shuffle()
	if lista.is_empty():
		return []
	return lista.slice(0, maxi(1, mini(cuantos, lista.size())))
