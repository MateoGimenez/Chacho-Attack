extends Luchador
## Enemigo con IA simple de beat 'em up:
##  1. Se acerca a un costado del Chacho (no se le pone encima).
##  2. Mientras espera su turno, se queda a distancia y "lo rodea".
##  3. Cuando le toca, se acerca y ataca. Máximo 2 atacando a la vez.
##
## Cada enemigo usa la hoja de su personaje (sprites/enemigos/<personaje>_16px.png):
##  - marinero (sable) y artillero (bayoneta): pegan dos veces de cerca (cuadros 1 y 5 del ataque)
##  - miquelete, moreno y natural (fusil): culatazo de cerca (cuadro 1) y DISPARO (cuadro 5).
##    A veces disparan desde lejos: la bala se esquiva cambiando de carril o se bloquea.
##  - coronel (jefe): el artillero con otra paleta, con bayoneta y disparo.

@export var nombre := "SOLDADO"
@export var personaje := "marinero"
## true = en el cuadro 5 del ataque dispara una bala (en vez de un segundo golpe)
@export var tirador := false
@export var tinte := Color.WHITE
@export var danio := 7
@export var danio_bala := 8
## Sonido del golpe de cerca ("" = espadazo, o culatazo si es tirador). Los agentes: "culatazo" (piña)
@export var sonido_golpe := ""
@export var puntos := 100
@export var es_jefe := false
## Mini jefe: muestra la barra arriba, pero al morir no termina el nivel
@export var mini_jefe := false
## Si es false, al morir queda tirado (la máquina rota del jefe final) en vez de desaparecer
var desaparecer_al_morir := true
## Probabilidad de soltar un item al morir (0 a 1)
@export var prob_item := 0.3
## Tiempo entre ataques (segundos, se elige al azar entre min y max)
@export var espera_min := 1.3
@export var espera_max := 2.4

const MAX_ATACANTES := 2
const ALCANCE := 26.0
const DISTANCIA_TIRO := 72.0   # desde dónde dispara cuando tira "de lejos"
const BALA := preload("res://scripts/bala.gd")

var _espera := 1.0
var _lado := 1.0  # 1 = se pone a la derecha del Chacho, -1 = a la izquierda
var _de_lejos := false  # este turno dispara desde lejos (solo tiradores)
var _jugador: Luchador
var _buscar := 0.0

## Para el fogonazo del disparo (lo dibuja nivel.gd)
signal fogonazo(donde: Vector2, direccion: float)


func _ready() -> void:
	sprite.sprite_frames = EnemigoFrames.obtener(personaje)
	sprite.offset = EnemigoFrames.OFFSET
	super._ready()
	add_to_group("enemigos")
	sprite.self_modulate = tinte
	_espera = randf_range(0.6, 1.6)
	_de_lejos = tirador and randf() < 0.55
	sprite.speed_scale = 1.0
	sprite.frame = randi() % 4  # que no respiren todos sincronizados


func _physics_process(delta: float) -> void:
	aplicar_empuje(delta)
	if estado != Estado.NORMAL:
		return
	# De a 2 jugadores va contra el más cercano (lo revisa cada tanto)
	_buscar -= delta
	if _jugador == null or _jugador.estado == Estado.MUERTO or _buscar <= 0.0:
		_buscar = 0.8
		var antes := _jugador
		_jugador = _jugador_mas_cercano()
		if _jugador == null:
			reproducir(&"quieto")
			return
		if _jugador != antes:
			_lado = signf(global_position.x - _jugador.global_position.x)
			if _lado == 0.0:
				_lado = 1.0

	_espera -= delta
	var max_atacantes := MAX_ATACANTES + (1 if Juego.dos_jugadores() else 0)
	var mi_turno := _espera <= 0.0 and _atacantes_actuales() < max_atacantes
	# Si no es su turno se queda más lejos, esperando
	var distancia := 47.5
	if mi_turno:
		distancia = DISTANCIA_TIRO if _de_lejos else 21.0
	var destino := _jugador.global_position + Vector2(_lado * distancia, 0)
	var hacia := destino - global_position
	hacia += _separacion()

	mirar_hacia(_jugador.global_position.x > global_position.x)

	var alineado := absf(_jugador.global_position.y - global_position.y) < 3.0
	if hacia.length() > 2.5 and not (mi_turno and _de_lejos and alineado and absf(hacia.x) < 10.0):
		var vel := velocidad * (1.0 if mi_turno else 0.6)
		position += hacia.normalized() * vel * delta
		reproducir(&"guardia" if mi_turno else &"caminar")
	else:
		reproducir(&"quieto")
		if mi_turno:
			_atacar()


func _atacar() -> void:
	estado = Estado.ATAQUE
	sprite.speed_scale = 0.8  # un poco más lento que el Chacho: se lee el ataque
	reiniciar(&"ataque")
	_destello(Color(1.9, 1.6, 1.1))  # brillo de aviso: "¡te va a pegar!"
	Sonido.tocar("aviso_enemigo", -10.0)
	_espera = randf_range(espera_min, espera_max)
	# Los tiradores eligen de nuevo si el próximo turno disparan de lejos
	_de_lejos = tirador and randf() < 0.55
	# A veces cambia de lado para rodear al jugador
	if randf() < 0.25:
		_lado = -_lado


func _al_cambiar_frame(anim: StringName, frame: int) -> void:
	if estado != Estado.ATAQUE or anim != &"ataque":
		return
	if frame == EnemigoFrames.CUADRO_GOLPE:
		_golpe_cuerpo_a_cuerpo()
	elif frame == EnemigoFrames.CUADRO_DISPARO:
		if tirador:
			_disparar()
		else:
			_golpe_cuerpo_a_cuerpo()


func _golpe_cuerpo_a_cuerpo() -> void:
	var cerca := _jugador != null and absf(_jugador.global_position.x - global_position.x) < ALCANCE + 8.0
	if cerca:
		mostrar_tajo(&"estocada", ALCANCE, 16.0, Color(1.0, 0.55, 0.45))
	var s := sonido_golpe if sonido_golpe != "" else ("espadazo" if not tirador else "culatazo")
	Sonido.tocar(s, -4.0)
	golpear(&"jugador", danio, 45.0, ALCANCE, 7.0)


func _disparar() -> void:
	var b := BALA.new()
	b.direccion = 1.0 if mira_derecha else -1.0
	b.danio = danio_bala
	b.position = position + Vector2(b.direccion * 24.0, 0)
	get_parent().add_child(b)
	Sonido.tocar("disparo")
	# fogonazo y humito en la punta del fusil
	fogonazo.emit(global_position + Vector2(b.direccion * 26.0, -22.0), b.direccion)


func morir() -> void:
	super.morir()
	remove_from_group("enemigos")
	if not desaparecer_al_morir:
		return
	# Parpadea y desaparece
	var t := create_tween()
	t.tween_interval(1.1)
	for i in 4:
		t.tween_property(self, "modulate:a", 0.2, 0.08)
		t.tween_property(self, "modulate:a", 1.0, 0.08)
	t.tween_callback(queue_free)


func _sonido_muerte() -> String:
	return "enemigo_cae"


func _jugador_mas_cercano() -> Luchador:
	var mejor: Luchador = null
	var dist := INF
	for n in get_tree().get_nodes_in_group("jugador"):
		var j := n as Luchador
		if j.estado == Estado.MUERTO:
			continue
		var d := j.global_position.distance_squared_to(global_position)
		if d < dist:
			dist = d
			mejor = j
	return mejor


func _atacantes_actuales() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e != self and (e as Luchador).estado == Estado.ATAQUE:
			n += 1
	return n


## Empuja suavemente para que los enemigos no se amontonen uno encima del otro
func _separacion() -> Vector2:
	var fuerza := Vector2.ZERO
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e == self:
			continue
		var d: Vector2 = global_position - (e as Node2D).global_position
		if d.length() < 13.0 and d.length() > 0.01:
			fuerza += d.normalized() * (13.0 - d.length())
	return fuerza
