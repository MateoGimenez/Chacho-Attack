class_name Bala
extends Node2D
## Bala de fusil. Viaja en línea recta por el "carril" (la Y de los pies del que disparó).
## Se esquiva cambiando de carril (arriba/abajo) o se para con el bloqueo mirando hacia ella.

const VELOCIDAD := 150.0   # px/s (la pantalla mide 240)
const DURACION := 1.6      # segundos antes de desaparecer
const ALTURA := 22.0       # a qué altura del piso se dibuja (la del caño del fusil)
const CARRIL := 6.0        # diferencia de Y que todavía cuenta como "mismo carril"

var direccion := 1.0
var danio := 8
var _vida := DURACION


func _ready() -> void:
	add_to_group("balas")


func _physics_process(delta: float) -> void:
	var antes := position.x
	position.x += direccion * VELOCIDAD * delta
	_vida -= delta
	if _vida <= 0.0:
		queue_free()
		return
	for n in get_tree().get_nodes_in_group("jugador"):
		var jugador := n as Luchador
		if jugador.estado == Luchador.Estado.MUERTO:
			continue
		if absf(jugador.global_position.y - global_position.y) > CARRIL:
			continue
		var x := jugador.global_position.x
		if x >= minf(antes, position.x) - 4.0 and x <= maxf(antes, position.x) + 4.0:
			jugador.recibir_golpe(danio, self, 30.0)
			queue_free()
			return


func _draw() -> void:
	# punta brillante + estela, en píxeles enteros
	var y := -ALTURA
	var estela_x := -7.0 if direccion > 0 else 2.0
	draw_rect(Rect2(estela_x, y, 6, 1), Color(1, 0.8, 0.4, 0.45))
	draw_rect(Rect2(-1, y, 3, 1), Color("#fff4c2"))
