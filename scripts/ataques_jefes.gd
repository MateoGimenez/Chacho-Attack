class_name AtaquesJefes
## Ataques especiales de los jefes (v7). Cada uno es un nodo que se maneja solo y se borra al terminar.
##
##   Estampida  → Paz: aviso en una franja del piso y después cruza la caballería. Se esquiva cambiando de carril.
##   Tintero    → Rosas: vuela en arco hasta donde estabas; la sombra marca dónde cae.
##   Libro      → Rosas: cae del cielo; la sombra crece antes del golpe. No se bloquea.
##   Onda       → Rosas: la onda del megáfono. Si te agarra sin bloquear, te aturde (caminás lento).
##   Billete    → jefe final: "bonos" que vuelan como naipes. Se esquivan caminando arriba/abajo.
##   Franja     → aviso rojo de un carril (la embestida de la máquina).
##
## Los que se ven "en el piso" (sombras, franjas) van en la capa nivel.avisos (debajo de todos).
## Los que vuelan van en nivel.mundo (ordenados por profundidad con los personajes).

const CABALLERIA := preload("res://sprites/jefes/caballeria.png")
const TINTERO := preload("res://sprites/jefes/tintero.png")
const LIBRO := preload("res://sprites/jefes/libro.png")
const BONOS := preload("res://sprites/jefes/bonos.png")


## Le pega a cada jugador vivo que cumpla la condición (una sola vez por ataque, con la lista "ya")
static func pegar(arbol: SceneTree, atacante: Node2D, ya: Array, danio: int, fuerza: float,
		condicion: Callable) -> int:
	var n := 0
	for nodo in arbol.get_nodes_in_group("jugador"):
		var j := nodo as Luchador
		if j == null or j.estado == Luchador.Estado.MUERTO or j in ya:
			continue
		if condicion.call(j):
			ya.append(j)
			if j.recibir_golpe(danio, atacante, fuerza):
				n += 1
	return n


# ------------------------------------------------------------------ aviso de franja
class Franja extends Node2D:
	## Rectángulo rojo que titila sobre un carril, de borde a borde de la pantalla
	var y0 := 100.0
	var y1 := 118.0
	var izq := 0.0
	var der := 240.0
	var direccion := 1.0   # para las flechitas
	var duracion := 1.2
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duracion:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var parpadeo := 0.16 + 0.14 * absf(sin(_t * 14.0))
		draw_rect(Rect2(izq, y0, der - izq, y1 - y0), Color(1.0, 0.15, 0.1, parpadeo))
		draw_rect(Rect2(izq, y0, der - izq, 1), Color(1, 0.3, 0.2, 0.7))
		draw_rect(Rect2(izq, y1 - 1, der - izq, 1), Color(1, 0.3, 0.2, 0.7))
		# flechas que corren en la dirección del ataque
		var centro := roundf((y0 + y1) / 2.0)
		var corrido := fmod(_t * 60.0, 24.0) * direccion
		var x := izq - 24.0
		while x < der + 24.0:
			var px := roundf(x + corrido)
			var d := direccion
			draw_colored_polygon(PackedVector2Array([Vector2(px, centro - 3), Vector2(px + 4 * d, centro),
				Vector2(px, centro + 3)]), Color(1, 0.85, 0.3, 0.75))
			x += 24.0


# ------------------------------------------------------------------ caballería (Paz)
class Estampida extends Node2D:
	## Aviso en una franja y después cruzan los jinetes de punta a punta.
	var nivel: Node
	var y0 := 100.0
	var y1 := 118.0
	var direccion := 1.0   # 1 = vienen de la izquierda
	var aviso := 1.4
	var cantidad := 5
	var danio := 16
	var imparable := true  # no se bloquea: te pisan
	var _ya: Array = []
	var _jinetes: Array[AnimatedSprite2D] = []
	var _t := 0.0
	var _salieron := false
	var _polvo := 0.0

	func _ready() -> void:
		var lim: Vector2 = nivel.limites()
		var f := Franja.new()
		f.y0 = y0
		f.y1 = y1
		f.izq = lim.x
		f.der = lim.y
		f.direccion = direccion
		f.duracion = aviso
		nivel.avisos.add_child(f)

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _salieron:
			if _t >= aviso:
				_salir()
			return
		var lim: Vector2 = nivel.limites()
		var quedan := 0
		_polvo -= delta
		for j in _jinetes:
			j.position.x += direccion * 235.0 * delta
			var adentro := j.position.x > lim.x - 40.0 and j.position.x < lim.y + 40.0
			if direccion > 0.0 and j.position.x < lim.y + 40.0 or direccion < 0.0 and j.position.x > lim.x - 40.0:
				quedan += 1
			if adentro and _polvo <= 0.0:
				nivel.polvo(j.position + Vector2(-direccion * 12.0, 0), 1.2)
			position = j.position  # para que el empujón vaya en la dirección de la carga
			var jx := j.position.x
			var cond := func(p: Luchador) -> bool:
				return p.position.y >= y0 - 2.0 and p.position.y <= y1 + 2.0 and absf(p.position.x - jx) < 14.0
			if AtaquesJefes.pegar(get_tree(), self, _ya, danio, 130.0, cond) > 0:
				nivel.temblar(0.2)
		if _polvo <= 0.0:
			_polvo = 0.09
		if quedan == 0:
			for j in _jinetes:
				j.queue_free()
			queue_free()

	func _salir() -> void:
		_salieron = true
		Sonido.tocar("galope", 0.0, 0.0)
		nivel.temblar(0.5)
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", 14.0)
		for k in 4:
			var at := AtlasTexture.new()
			at.atlas = CABALLERIA
			at.region = Rect2(k * 48, 0, 48, 40)
			frames.add_frame("default", at)
		var lim: Vector2 = nivel.limites()
		var inicio := lim.x - 30.0 if direccion > 0.0 else lim.y + 30.0
		for i in cantidad:
			var j := AnimatedSprite2D.new()
			j.sprite_frames = frames
			j.offset = Vector2(0, -18)   # los cascos quedan en la posición del nodo
			j.flip_h = direccion < 0.0
			var fila := float(i % 3) / 2.0
			j.position = Vector2(inicio - direccion * (i * 30.0 + randf_range(0, 8)),
				roundf(lerpf(y0 + 3.0, y1 - 2.0, fila)))
			j.frame = i % 4
			j.play()
			nivel.mundo.add_child(j)
			_jinetes.append(j)


# ------------------------------------------------------------------ sombra que crece (lo que cae)
class Sombra extends Node2D:
	var radio := 10.0
	var duracion := 0.9
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / duracion, 0.15, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, radio * k, Color(0, 0, 0, 0.25 + 0.25 * k))
		# borde que titila: "¡salí de acá!"
		if fmod(_t, 0.2) < 0.1:
			draw_arc(Vector2.ZERO, radio, 0, TAU, 20, Color(1, 0.3, 0.2, 0.7), 1.0)


# ------------------------------------------------------------------ tintero (Rosas)
class Tintero extends Node2D:
	var nivel: Node
	var desde := Vector2.ZERO
	var hasta := Vector2.ZERO
	var duracion := 0.85
	var altura := 34.0
	var danio := 9
	var _t := 0.0
	var _sprite: Sprite2D
	var _sombra: Sombra
	var _ya: Array = []

	func _ready() -> void:
		position = desde
		_sprite = Sprite2D.new()
		_sprite.texture = TINTERO
		add_child(_sprite)
		_sombra = Sombra.new()
		_sombra.position = hasta
		_sombra.radio = 11.0
		_sombra.duracion = duracion
		nivel.avisos.add_child(_sombra)
		Sonido.tocar("lanzar", -2.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		var k := minf(_t / duracion, 1.0)
		position = desde.lerp(hasta, k)
		_sprite.position = Vector2(0, -4.0 * altura * k * (1.0 - k) - 12.0 * (1.0 - k)).round()
		_sprite.rotation = roundf(k * 6.0) * PI / 2.0
		if k >= 1.0:
			_romper()

	func _romper() -> void:
		Sonido.tocar("tintero")
		nivel.chispas(hasta + Vector2(0, -3), [Color("#1a1c3a"), Color("#2c3a78"), Color("#0d0d18"), Color("#c8d6f0")], 18)
		var centro := hasta
		var cond := func(p: Luchador) -> bool:
			return absf(p.position.x - centro.x) < 13.0 and absf(p.position.y - centro.y) < 7.0
		AtaquesJefes.pegar(get_tree(), self, _ya, danio, 45.0, cond)
		var mancha := Mancha.new()
		mancha.position = hasta
		nivel.avisos.add_child(mancha)
		_sombra.queue_free()
		queue_free()


class Mancha extends Node2D:
	## Charco de tinta (solo adorno), se borra solo
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		modulate.a = clampf(3.0 - _t, 0.0, 1.0)
		if _t > 3.0:
			queue_free()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 9.0, Color("#141634"))
		draw_circle(Vector2(6, 4), 3.0, Color("#141634"))
		draw_circle(Vector2(-7, -3), 2.5, Color("#1d2550"))


# ------------------------------------------------------------------ libro que cae (Rosas)
class Libro extends Node2D:
	var nivel: Node
	var aviso := 0.95
	var danio := 13
	var imparable := true   # cae de arriba: no se bloquea
	var _t := 0.0
	var _sprite: Sprite2D
	var _sombra: Sombra
	var _ya: Array = []

	func _ready() -> void:
		_sprite = Sprite2D.new()
		_sprite.texture = LIBRO
		_sprite.position = Vector2(0, -150)
		_sprite.visible = false
		add_child(_sprite)
		_sombra = Sombra.new()
		_sombra.position = position
		_sombra.radio = 13.0
		_sombra.duracion = aviso
		nivel.avisos.add_child(_sombra)

	func _physics_process(delta: float) -> void:
		_t += delta
		var falta := aviso - _t
		if falta > 0.35:
			return
		_sprite.visible = true
		if falta > 0.0:
			var k := 1.0 - falta / 0.35
			_sprite.position = Vector2(0, roundf(lerpf(-150.0, -6.0, k * k)))
			return
		Sonido.tocar("libro")
		nivel.temblar(0.15)
		nivel.polvo(position, 1.5)
		var centro := position
		var cond := func(p: Luchador) -> bool:
			return absf(p.position.x - centro.x) < 14.0 and absf(p.position.y - centro.y) < 7.0
		AtaquesJefes.pegar(get_tree(), self, _ya, danio, 90.0, cond)
		_sombra.queue_free()
		# el libro queda tirado un ratito y se desvanece
		set_physics_process(false)
		_sprite.position = Vector2(0, -6)
		var tw := create_tween()
		tw.tween_interval(0.8)
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)


# ------------------------------------------------------------------ onda del megáfono (Rosas)
class Onda extends Node2D:
	var direccion := 1.0
	var alcance := 150.0
	var velocidad := 115.0
	var danio := 4
	var aturde := 2.2
	var _recorrido := 0.0
	var _ya: Array = []

	func _physics_process(delta: float) -> void:
		_recorrido += velocidad * delta
		queue_redraw()
		var frente := position.x + direccion * _recorrido
		var y := position.y
		for nodo in get_tree().get_nodes_in_group("jugador"):
			var j := nodo as Luchador
			if j == null or j.estado == Luchador.Estado.MUERTO or j in _ya:
				continue
			if absf(j.position.y - y) > 12.0 or absf(j.position.x - frente) > 6.0:
				continue
			_ya.append(j)
			# bloqueando de frente a la onda no te aturde
			var de_frente: bool = j.mira_derecha == (direccion < 0.0)
			if j.estado == Luchador.Estado.BLOQUEO and de_frente:
				Sonido.tocar("bloqueo")
				continue
			var golpe := Node2D.new()   # desde dónde "viene" el golpe (para el empujón)
			add_child(golpe)
			golpe.global_position = Vector2(frente - direccion * 10.0, y)
			if j.recibir_golpe(danio, golpe, 20.0) and j.has_method("aturdir"):
				j.call("aturdir", aturde)
				Sonido.tocar("aturdido", 0.0, 0.0)
			golpe.queue_free()
		if _recorrido >= alcance:
			queue_free()

	func _draw() -> void:
		var a := clampf(1.0 - _recorrido / alcance, 0.0, 1.0)
		for i in 3:
			var r := _recorrido - i * 7.0
			if r <= 2.0:
				continue
			var alto := 4.0 + r * 0.09
			var x := roundf(r * direccion)
			var c := Color(1.0, 0.92, 0.55, a * (1.0 - i * 0.28))
			# ")))" de píxeles: un arco hecho con rectángulos
			for k in range(-int(alto), int(alto) + 1, 2):
				var curva := (1.0 - pow(float(k) / alto, 2.0)) * 3.0
				draw_rect(Rect2(x + roundf(curva * direccion), -22.0 + k, 1, 2), c)


# ------------------------------------------------------------------ billetes (jefe final)
class Billete extends Node2D:
	var velocidad := Vector2(115, 0)
	var danio := 6
	var color := 0   # 0 verde, 1 violeta, 2 naranja
	var vida := 2.2
	var altura := 20.0
	var _t := 0.0
	var _sprite: Sprite2D
	var _ya: Array = []

	func _ready() -> void:
		add_to_group("proyectiles")
		_sprite = Sprite2D.new()
		_sprite.texture = BONOS
		_sprite.region_enabled = true
		_sprite.position = Vector2(0, -altura)
		add_child(_sprite)

	func _physics_process(delta: float) -> void:
		_t += delta
		position += velocidad * delta
		position.y = clampf(position.y, Luchador.piso_arriba - 2.0, Luchador.piso_abajo + 2.0)
		# gira como un naipe: alterna de frente y de canto
		var cuadro := int(_t * 12.0) % 2
		_sprite.region_rect = Rect2(cuadro * 10, color * 6, 10, 6)
		var aqui := position
		var cond := func(p: Luchador) -> bool:
			return absf(p.position.x - aqui.x) < 7.0 and absf(p.position.y - aqui.y) < 5.0
		if AtaquesJefes.pegar(get_tree(), self, _ya, danio, 25.0, cond) > 0 or _t > vida:
			queue_free()
