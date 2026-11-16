extends Luchador
## Personaje jugable: el CHACHO (lanza) o FACUNDO QUIROGA (sable).
## Los datos de cada uno (combo, ulti, sprites) están en scripts/personajes.gd.
##
## numero = 1 o 2: el jugador 2 usa las acciones con "_2" al final (ver entradas.gd).
##
## RABIA: la barra se llena tomando VINO (y un poco pegando y recibiendo golpes).
## Con la barra llena, el botón RABIA activa la ULTI y el MODO RABIA: durante unos
## segundos pega más fuerte, es más rápido y no lo frenan los golpes.
##   Chacho  → RABIA RIOJANA: barrido gigante alrededor.
##   Quiroga → TIGRE DE LOS LLANOS: embestida que cruza la pantalla con zarpazos.

signal golpe_acertado(fuerte: bool)
signal especial_usado(quien: Node2D)
signal rabia_cambio(valor: float, activa: bool)
signal puntos_extra(cantidad: int)
signal item_agarrado(texto: String, color: Color, donde: Vector2)

const RABIA_MAX := 100.0
const DURACION_RABIA := 8.0
const RABIA_POR_VINO := 40.0
const RABIA_POR_GOLPE := 3.0          # por cada enemigo que le pegás
const RABIA_POR_DANIO_RECIBIDO := 0.6  # por cada punto de vida que perdés

const COLOR_TAJO := Color("#fff4d6")
const COLOR_RABIA := Color("#ff5a3c")
const COLOR_TIGRE := Color("#ffb347")

## Quién es y qué jugador lo controla (se asignan antes de agregarlo a la escena)
@export var personaje := "chacho"
@export var numero := 1

var datos: Dictionary
var rabia := 0.0
var en_rabia := false
var multiplicador_danio := 1.0
var _rabia_restante := 0.0
var _proximo_fantasma := 0.0

var _combo: Array = []
var _golpe: Dictionary = {}
var _paso_combo := 0
var _quiere_seguir := false
var _golpe_hecho := false
var _es_especial := false

# Embestida de Quiroga
var _embistiendo := 0.0
## Segundos que le quedan de aturdido (el megáfono de Rosas): camina a menos de la mitad
var _aturdido := 0.0
var _ya_zarpados: Array = []


func _ready() -> void:
	datos = Personajes.datos(personaje)
	_combo = datos["combo"]
	sprite.sprite_frames = Personajes.frames(personaje)
	sprite.offset = datos["offset"]
	super._ready()
	add_to_group("jugador")


func _draw() -> void:
	super._draw()
	# De a 2: una flechita del color de cada jugador arriba de la cabeza
	if Juego.dos_jugadores():
		var c := Color("#f2b84b") if numero == 1 else Color("#9fd8ff")
		var y := -44.0
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(PackedVector2Array([Vector2(-2, y), Vector2(3, y), Vector2(0.5, y + 3)]), c)
	# Aturdido: estrellitas girando sobre la cabeza
	if _aturdido > 0.0:
		draw_set_transform(Vector2.ZERO)
		var giro := Time.get_ticks_msec() / 160.0
		for i in 3:
			var ang := giro + TAU * i / 3.0
			var p := Vector2(cos(ang) * 7.0, -38.0 + sin(ang) * 2.0).round()
			draw_rect(Rect2(p, Vector2(2, 2)), Color("#ffe066") if i != 1 else Color.WHITE)


## Nombre de la acción para este jugador ("atacar" o "atacar_2")
func _a(accion: String) -> String:
	return accion if numero == 1 else accion + "_2"


func _physics_process(delta: float) -> void:
	aplicar_empuje(delta)
	_actualizar_rabia(delta)
	if _aturdido > 0.0:
		_aturdido = maxf(_aturdido - delta, 0.0)
		queue_redraw()
	if _embistiendo > 0.0:
		_seguir_embestida(delta)
		return

	match estado:
		Estado.MUERTO, Estado.DOLOR:
			return
		Estado.ATAQUE:
			# Apretar atacar durante un golpe encadena el siguiente (combo)
			if Input.is_action_just_pressed(_a("atacar")):
				_quiere_seguir = true
			return

	# Estado NORMAL o BLOQUEO
	if Input.is_action_just_pressed(_a("especial")) and rabia >= RABIA_MAX and not en_rabia:
		_activar_rabia()
		return
	if Input.is_action_just_pressed(_a("atacar")):
		_empezar_golpe(0)
		return
	if Input.is_action_pressed(_a("bloquear")):
		estado = Estado.BLOQUEO
		reproducir(&"bloqueo")
		return
	estado = Estado.NORMAL

	var dir := Input.get_vector(_a("mover_izq"), _a("mover_der"), _a("mover_arriba"), _a("mover_abajo"))
	if dir.length() > 0.1:
		var corre := Input.is_action_pressed(_a("correr"))
		var vel := velocidad * (1.8 if corre else 1.0) * (1.2 if en_rabia else 1.0)
		if _aturdido > 0.0:
			vel *= 0.4
		# En los beat 'em ups el movimiento en profundidad es más lento
		position += Vector2(dir.x, dir.y * 0.65) * vel * delta
		if absf(dir.x) > 0.1:
			mirar_hacia(dir.x > 0.0)
		reproducir(&"correr" if corre else &"caminar")
	else:
		reproducir(&"quieto")


# ---------- Ataques ----------

func _empezar_golpe(paso: int) -> void:
	_paso_combo = paso
	_es_especial = false
	_lanzar(_combo[paso])


func _lanzar(golpe: Dictionary) -> void:
	_golpe = golpe
	estado = Estado.ATAQUE
	_golpe_hecho = false
	_quiere_seguir = false
	sprite.speed_scale = golpe["vel"] * (1.25 if en_rabia else 1.0)
	reiniciar(golpe["anim"])
	# cada golpe del combo suena más pesado que el anterior
	if not _es_especial:
		Sonido.tocar(datos["sonido"] % (_paso_combo + 1))


func _al_cambiar_frame(_anim: StringName, frame: int) -> void:
	if estado != Estado.ATAQUE or _golpe_hecho or _golpe.is_empty() or frame != _golpe["frame"]:
		return
	_golpe_hecho = true

	# Pequeño avance al pegar: el cuerpo acompaña el arma
	var avance: float = _golpe["avance"]
	empuje = avance if mira_derecha else -avance
	var color := COLOR_RABIA if en_rabia else COLOR_TAJO
	mostrar_tajo(_golpe.get("tajo", &"estocada"), _golpe["alcance"], _golpe["altura"], color)
	if _paso_combo == 2 or _es_especial:
		aplastar(Vector2(1.1, 0.94))
		for i in 3:
			get_tree().create_timer(0.03 * i).timeout.connect(fantasma.bind(Color(color, 0.45)))

	var danio := int(_golpe["danio"] * multiplicador_danio)
	var args := [danio, _golpe["fuerza"], _golpe["alcance"], _golpe["profundidad"], _golpe["ambos"]]
	var a_enemigos: int = golpear.callv([&"enemigos"] + args)
	var a_barriles: int = golpear.callv([&"rompibles"] + args)
	if a_enemigos > 0:
		sumar_rabia(RABIA_POR_GOLPE * a_enemigos)
	if a_enemigos + a_barriles > 0:
		golpe_acertado.emit(_es_especial or _paso_combo == 2)


func _fin_animacion(anim: StringName) -> void:
	if _embistiendo > 0.0:
		return
	if estado == Estado.ATAQUE:
		sprite.speed_scale = 1.0
		if _quiere_seguir and not _es_especial and _paso_combo < _combo.size() - 1:
			_empezar_golpe(_paso_combo + 1)
			return
	super._fin_animacion(anim)


## Lo frena un rato (la onda del megáfono). Bloqueando de frente no le hace nada.
func aturdir(segundos: float) -> void:
	_aturdido = maxf(_aturdido, segundos)
	queue_redraw()


func esta_aturdido() -> bool:
	return _aturdido > 0.0


func recibir_golpe(danio: int, atacante: Node2D, fuerza: float) -> bool:
	if _embistiendo > 0.0:
		return false  # durante la embestida no le entran golpes
	var vida_antes := vida
	var entro := super.recibir_golpe(danio, atacante, fuerza)
	if entro:
		sumar_rabia((vida_antes - vida) * RABIA_POR_DANIO_RECIBIDO)
	return entro


## Además del golpe, se queja
func _sonido_impacto(fuerza: float) -> String:
	Sonido.tocar("chacho_dolor", 0.0, 0.07 if personaje == "chacho" else 0.0)
	return super._sonido_impacto(fuerza)


func _sonido_muerte() -> String:
	return "chacho_muere"


# ---------- Rabia ----------

func sumar_rabia(cantidad: float) -> void:
	if en_rabia or cantidad <= 0.0:
		return
	var antes := rabia
	rabia = minf(rabia + cantidad, RABIA_MAX)
	rabia_cambio.emit(rabia, false)
	if antes < RABIA_MAX and rabia >= RABIA_MAX:
		item_agarrado.emit("¡RABIA LISTA!", COLOR_RABIA, global_position + Vector2(0, -50))
		Sonido.tocar("rabia_lista", 0.0, 0.0)


func _activar_rabia() -> void:
	en_rabia = true
	_rabia_restante = DURACION_RABIA
	multiplicador_danio = 1.5
	super_armadura = true
	sprite.self_modulate = Color(1.35, 0.8, 0.72)
	_es_especial = true
	hacer_invulnerable(0.9)
	if datos["ulti"] == "embestida":
		_empezar_embestida()
	else:
		_lanzar(datos["especial"])
		Sonido.tocar("rabia", 0.0, 0.0)
	especial_usado.emit(self)


func _actualizar_rabia(delta: float) -> void:
	if not en_rabia:
		return
	_rabia_restante -= delta
	rabia = RABIA_MAX * maxf(_rabia_restante, 0.0) / DURACION_RABIA
	rabia_cambio.emit(rabia, true)
	# Latido rojo + fantasmas mientras se mueve o pega
	var latido := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
	sprite.self_modulate = Color(1.2 + 0.3 * latido, 0.75, 0.7)
	_proximo_fantasma -= delta
	if _proximo_fantasma <= 0.0 and sprite.animation != &"quieto":
		_proximo_fantasma = 0.07
		fantasma(Color(1.0, 0.3, 0.2, 0.4), 0.2)
	if _rabia_restante <= 0.0:
		en_rabia = false
		rabia = 0.0
		multiplicador_danio = 1.0
		super_armadura = false
		sprite.self_modulate = Color.WHITE
		rabia_cambio.emit(0.0, false)


# ---------- Ulti de Quiroga: TIGRE DE LOS LLANOS ----------

func _empezar_embestida() -> void:
	var e: Dictionary = datos["especial"]
	estado = Estado.ATAQUE
	_embistiendo = e["duracion"]
	_ya_zarpados.clear()
	sprite.speed_scale = 1.0
	reiniciar(&"embestida")
	Sonido.tocar("tigre", 0.0, 0.0)
	# zarpazo grande al arrancar
	_zarpazo(global_position + Vector2(18.0 if mira_derecha else -18.0, -20.0), 1.6)


func _seguir_embestida(delta: float) -> void:
	var e: Dictionary = datos["especial"]
	var dir := 1.0 if mira_derecha else -1.0
	position.x += dir * e["distancia"] / e["duracion"] * delta
	position.y = clampf(position.y, piso_arriba, piso_abajo)
	_proximo_fantasma -= delta
	if _proximo_fantasma <= 0.0:
		_proximo_fantasma = 0.03
		fantasma(Color(COLOR_TIGRE, 0.5), 0.22)
	for grupo in [&"enemigos", &"rompibles"]:
		for n in get_tree().get_nodes_in_group(grupo):
			var otro := n as Luchador
			if otro == null or otro.estado == Estado.MUERTO or otro in _ya_zarpados:
				continue
			var d := otro.global_position - global_position
			if absf(d.y) <= e["profundidad"] and absf(d.x) <= e["ancho"]:
				_ya_zarpados.append(otro)
				if otro.recibir_golpe(int(e["danio"] * multiplicador_danio), self, e["fuerza"]):
					_zarpazo(otro.global_position + Vector2(0, -18), 1.0)
					golpe_acertado.emit(true)
	_embistiendo -= delta
	if _embistiendo <= 0.0:
		_embistiendo = 0.0
		estado = Estado.NORMAL
		_es_especial = false
		reproducir(&"quieto")


func _zarpazo(donde: Vector2, tamanio: float) -> void:
	var z := Zarpazo.new()
	z.tamanio = tamanio
	z.position = donde
	z.z_index = 50
	get_parent().add_child(z)


## Tres arañazos de tigre en diagonal que se borran solos
class Zarpazo extends Node2D:
	const DURACION := 0.3
	var tamanio := 1.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= DURACION:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - _t / DURACION
		var largo := 14.0 * tamanio * minf(1.0, _t / 0.06)
		for i in 3:
			var x := (i - 1) * 5.0 * tamanio
			var desde := Vector2(x - largo * 0.35, -largo * 0.5).round()
			var hasta := Vector2(x + largo * 0.35, largo * 0.5).round()
			draw_line(desde + Vector2(1, 0), hasta + Vector2(1, 0), Color(0.45, 0.08, 0.05, a * 0.8), 1.0)
			draw_line(desde, hasta, Color(1.0, 0.85 - 0.35 * (1.0 - a), 0.45, a), 2.0 if tamanio > 1.2 else 1.0)


# ---------- Items ----------

func agarrar_item(tipo: Item.Tipo) -> void:
	var donde := global_position + Vector2(0, -44)
	match tipo:
		Item.Tipo.CHORIPAN:
			Sonido.tocar("comer")
			_curar(50)
			item_agarrado.emit("CHORIPAN +50", Color("#ffd36b"), donde)
		Item.Tipo.ALBAHACA:
			Sonido.tocar("comer")
			_curar(20)
			item_agarrado.emit("ALBAHACA +20", Color("#9be07a"), donde)
		Item.Tipo.VINO:
			Sonido.tocar("vino")
			if en_rabia:
				_rabia_restante = minf(_rabia_restante + 2.0, DURACION_RABIA)
				item_agarrado.emit("VINO +2 SEG", Color("#ff6f8a"), donde)
			else:
				sumar_rabia(RABIA_POR_VINO)
				item_agarrado.emit("VINO +40 RABIA", Color("#ff6f8a"), donde)
		Item.Tipo.HARINA:
			Sonido.tocar("harina", 0.0, 0.0)
			puntos_extra.emit(300)
			item_agarrado.emit("HARINA +300", Color("#fff1d6"), donde)


func _curar(cantidad: int) -> void:
	vida = mini(vida + cantidad, vida_max)
	vida_cambio.emit(vida, vida_max)
