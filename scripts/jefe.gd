extends "res://scripts/enemigo.gd"
## Base de los JEFES (v7). Cada jefe tiene su script que extiende este:
##   jefe_paz.gd · jefe_rivadavia.gd · jefe_rosas.gd · jefe_final.gd
## Los datos (vida, velocidad, nombre) están en TIPOS de nivel.gd; las oleadas en juego.gd.
##
## Reglas comunes (estilo jefes de Sega / Capcom):
##  - Entran caminando desde el costado y después nunca salen de la pantalla.
##  - No salen volando con los golpes.
##  - Si les pegan muchas veces seguidas se "sacuden": una onda que empuja a todos (así no
##    se los puede trabar con el combo infinito, pero pegarles sigue rindiendo).

@export var subtitulo := ""
## Cuántos golpes seguidos aguanta antes de sacudirse
@export var aguante := 6

var nivel: Node
var _entrando := true
var _golpes_seguidos := 0
var _ultimo_golpe := 0.0
var _textos_hasta := 0.0  # para no llenar la pantalla de textos repetidos


func _ready() -> void:
	super._ready()
	nivel = get_tree().current_scene
	puede_volar = false
	add_to_group("jefes")


## true si este jefe se quedó solo (el dúo: murió el compañero) → se enoja
func solo() -> bool:
	for n in get_tree().get_nodes_in_group("jefes"):
		if n != self and (n as Luchador).estado != Estado.MUERTO:
			return false
	return true


func izq() -> float:
	return nivel.limites().x + 12.0


func der() -> float:
	return nivel.limites().y - 12.0


## Mientras entra camina hacia adentro; después queda siempre dentro de la pantalla
func limitar(delta: float) -> bool:
	if _entrando:
		var centro: float = (izq() + der()) / 2.0
		mirar_hacia(centro > position.x)
		position.x = move_toward(position.x, centro, velocidad * 1.6 * delta)
		reproducir(&"caminar")
		if position.x > izq() + 10.0 and position.x < der() - 10.0:
			_entrando = false
		return true
	position.x = clampf(position.x, izq(), der())
	position.y = clampf(position.y, piso_arriba, piso_abajo)
	return false


## true si el atacante está del lado al que mira el jefe
func de_frente(atacante: Node2D) -> bool:
	return (atacante.global_position.x > global_position.x) == mira_derecha


func buscar_jugador(delta: float) -> Luchador:
	_buscar -= delta
	if _jugador == null or _jugador.estado == Estado.MUERTO or _buscar <= 0.0:
		_buscar = 0.8
		_jugador = _jugador_mas_cercano()
	return _jugador


## Texto flotante sobre el jefe, como mucho uno cada 0,7 s
func decir(t: String, color := Color.WHITE) -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora < _textos_hasta:
		return
	_textos_hasta = ahora + 0.7
	nivel.texto(t, color, global_position + Vector2(0, -46))


## Golpe de contacto mientras corre o embiste: le pega a los jugadores cerca (una vez cada uno)
func pegar_contacto(ya: Array, danio_: int, fuerza: float, dx: float, dy: float) -> int:
	var yo := self
	var cond := func(p: Luchador) -> bool:
		return absf(p.position.x - yo.position.x) < dx and absf(p.position.y - yo.position.y) < dy
	return AtaquesJefes.pegar(get_tree(), self, ya, danio_, fuerza, cond)


func recibir_golpe(danio_: int, atacante: Node2D, fuerza: float) -> bool:
	var entro := super.recibir_golpe(danio_, atacante, fuerza)
	if entro and atacante.is_in_group("jugador") and estado != Estado.MUERTO:
		var ahora := Time.get_ticks_msec() / 1000.0
		_golpes_seguidos = _golpes_seguidos + 1 if ahora - _ultimo_golpe < 1.3 else 1
		_ultimo_golpe = ahora
		if _golpes_seguidos >= aguante:
			_golpes_seguidos = 0
			sacudirse.call_deferred()
	return entro


## Onda que empuja a todos los jugadores cerca (a los dos lados)
func sacudirse() -> void:
	if estado == Estado.MUERTO:
		return
	_destello(Color(2.4, 2.0, 1.4))
	aplastar(Vector2(1.25, 0.85))
	Sonido.tocar("golpe_fuerte")
	nivel.temblar(0.2)
	nivel.polvo(global_position, 1.6)
	var yo := self
	var cond := func(p: Luchador) -> bool:
		return absf(p.position.x - yo.position.x) < 30.0 + ancho and absf(p.position.y - yo.position.y) < 12.0
	AtaquesJefes.pegar(get_tree(), self, [], 4, 110.0, cond)


func _sonido_muerte() -> String:
	return "golpe_fuerte"
