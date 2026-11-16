class_name Item
extends Node2D
## Comida y objetos que se agarran pasando por encima.

enum Tipo { CHORIPAN, VINO, ALBAHACA, HARINA }

const ANIMACIONES := [&"choripan", &"vino", &"albahaca", &"harina"]

@export var tipo: Tipo = Tipo.CHORIPAN

var _agarrado := false

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("items")
	sprite.play(ANIMACIONES[tipo])
	# Pequeño salto al aparecer + flotar
	sprite.position.y = -6.0
	var t := create_tween()
	t.tween_property(sprite, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.3))


func _physics_process(_delta: float) -> void:
	if _agarrado:
		return
	for n in get_tree().get_nodes_in_group("jugador"):
		var j := n as Luchador
		if j.estado == Luchador.Estado.MUERTO:
			continue
		var d := j.global_position - global_position
		if absf(d.x) < 9.0 and absf(d.y) < 6.0:
			_agarrar(j)
			return


func _agarrar(j: Luchador) -> void:
	_agarrado = true
	j.call("agarrar_item", tipo)
	var t := create_tween().set_parallel()
	t.tween_property(self, "position:y", position.y - 12.0, 0.25)
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(queue_free)
