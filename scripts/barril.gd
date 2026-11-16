extends Luchador
## Barril que se rompe a lanzazos y suelta comida.
## Hereda de Luchador para poder recibir golpes igual que un enemigo,
## pero no se mueve, no ataca y no sale volando.

## Qué suelta al romperse. Si es -1, el nivel elige comida al azar.
@export var item_fijo := -1
@export var puntos := 50


func _ready() -> void:
	puede_volar = false
	super._ready()
	add_to_group("rompibles")


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.35))


func _fin_animacion(anim: StringName) -> void:
	if estado == Estado.DOLOR:
		estado = Estado.NORMAL
		sprite.play(&"rajado")


func _sonido_impacto(_fuerza: float) -> String:
	return "barril_golpe"


func _sonido_muerte() -> String:
	return "barril_rompe"


func morir() -> void:
	super.morir()
	remove_from_group("rompibles")
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
