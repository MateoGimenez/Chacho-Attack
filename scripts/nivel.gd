extends Node2D
## Escena de nivel (una sola para los 3 escenarios).
## Lee de Juego.config() el fondo, el piso, las oleadas y los items.
##
## Puede jugarse de a 1 o de a 2 (Juego.personajes). Los jugadores se crean en _crear_jugadores().
## La cámara avanza con los jugadores. Al llegar a cierto punto aparece una OLEADA:
## la cámara se traba hasta que mueren todos, y después "¡ADELANTE!".
## La última oleada de cada nivel es el JEFE (v7): Paz en la Catedral, Rivadavia y Rosas en el
## Superdomo y el Tesorero (con su máquina de obra pública) en la Chaya. Al derrotarlo se pasa de nivel.
## Los jefes usan esta escena para avisos, temblores y polvo: ver "API para los jefes" más abajo.

const ESCENA_JUGADOR := preload("res://escenas/jugador.tscn")
const ESCENA_ENEMIGO := preload("res://escenas/enemigo.tscn")
const ESCENA_ITEM := preload("res://escenas/item.tscn")
const ESCENA_BARRIL := preload("res://escenas/barril.tscn")
const MENU := "res://menu/menu.tscn"
const COLORES_MADERA := [Color("#8a5a32"), Color("#5e3a1f"), Color("#b07a45"), Color("#3d3a3a")]

const MITAD_PANTALLA := 120.0

## Tipos de enemigos. Para balancear, cambiá estos números.
## Tipos de enemigo que se usan en las oleadas de juego.gd.
## "personajes": de qué hojas sale cada uno (se elige uno al azar al aparecer).
##   soldado  → de cerca: marinero (sable) y artillero (bayoneta). Pegan 2 veces por ataque.
##   sargento → fusileros: miquelete, moreno y natural. Culatazo de cerca y disparo (a veces de lejos).
##   jefe     → el CORONEL (artillero con otra paleta): súper armadura, bayoneta y disparo.
## Escala siempre 1: en pixel art, agrandar 1,1 o 1,35 deforma los píxeles.
const TIPOS := {
	"soldado": {"nombre": "SOLDADO", "personajes": ["marinero", "artillero"], "vida_max": 40,
		"velocidad": 27.5, "danio": 6, "puntos": 100, "prob_item": 0.35},
	"sargento": {"nombre": "FUSILERO", "personajes": ["miquelete", "moreno", "natural"], "vida_max": 60,
		"velocidad": 24.0, "danio": 8, "danio_bala": 9, "tirador": true, "puntos": 250, "prob_item": 0.7,
		"espera_min": 1.4, "espera_max": 2.4},
	# mini jefe de la Chaya (muestra barra, pero no termina el nivel)
	"coronel": {"nombre": "CORONEL", "personajes": ["coronel"], "vida_max": 200, "velocidad": 25.0,
		"danio": 10, "danio_bala": 11, "tirador": true, "puntos": 1500, "prob_item": 1.0,
		"super_armadura": true, "mini_jefe": true, "espera_min": 0.9, "espera_max": 1.5},
	# los matones de negro que cuidan al jefe final
	# los agentes de traje negro que cuidan al jefe final (fuentes/gen_jefe_final.py). Pelean a piñas.
	"guardia": {"nombre": "GUARDAESPALDAS", "personajes": ["agente_1", "agente_2", "agente_3"], "vida_max": 45,
		"velocidad": 30.0, "danio": 7, "puntos": 150, "prob_item": 0.4, "sonido_golpe": "culatazo"},

	# ---- JEFES (v7). "script" = su comportamiento. Arte provisorio: fuentes/gen_jefes.py
	"paz": {"script": "res://scripts/jefe_paz.gd", "nombre": "GRAL. PAZ", "subtitulo": "EL MANCO",
		"personajes": ["paz"], "vida_max": 320, "aguante": 4, "velocidad": 19.0, "danio": 8, "puntos": 5000,
		"es_jefe": true, "espera_min": 0.6, "espera_max": 1.2},
	"rivadavia": {"script": "res://scripts/jefe_rivadavia.gd", "nombre": "RIVADAVIA", "subtitulo": "",
		"personajes": ["rivadavia"], "vida_max": 200, "aguante": 4, "velocidad": 36.0, "danio": 8, "puntos": 4000,
		"es_jefe": true, "espera_min": 0.7, "espera_max": 1.3},
	"rosas": {"script": "res://scripts/jefe_rosas.gd", "nombre": "ROSAS", "subtitulo": "",
		"personajes": ["rosas"], "vida_max": 240, "aguante": 3, "super_armadura": true, "velocidad": 30.0, "danio": 6, "puntos": 4000,
		"es_jefe": true, "espera_min": 2.0, "espera_max": 2.8},
	"tesorero": {"script": "res://scripts/jefe_final.gd", "nombre": "Quintela", "subtitulo": "Y SU CUSTODIA",
		"personajes": ["tesorero"], "vida_max": 520, "velocidad": 24.0, "danio": 8, "puntos": 10000,
		"es_jefe": true, "espera_min": 1.8, "espera_max": 2.4},
}

enum Fase { AVANZANDO, PELEANDO, SALIENDO, FIN }

var fase := Fase.AVANZANDO
var puntos := 0
var ancho_nivel := 960.0
var _cfg: Dictionary
var _oleadas: Array
var _oleada := 0
var _vivos := 0
var _por_aparecer := 0
var _camara_x := MITAD_PANTALLA
var _camara_suave := MITAD_PANTALLA
var _temblor := 0.0

@onready var fondo: Sprite2D = $Fondo
@onready var mundo: Node2D = $Mundo
var jugadores: Array[Luchador] = []
var jugador: Luchador  # el jugador 1 (atajo)
@onready var camara: Camera2D = $Camara
@onready var hud = $HUD  # sin tipo para poder llamar las funciones de hud.gd
## Capa "en el piso", debajo de los personajes: sombras de lo que cae, franjas de aviso, charcos
var avisos: Node2D
## Los que tienen barra arriba (jefes y mini jefes). El dúo comparte una sola barra.
var _con_barra: Array[Luchador] = []


func _ready() -> void:
	Engine.time_scale = 1.0
	randomize()
	_cargar_escenario()
	avisos = Node2D.new()
	avisos.name = "Avisos"
	add_child(avisos)
	move_child(avisos, mundo.get_index())

	_crear_jugadores()
	hud.configurar(jugadores)
	hud.actualizar_puntos(puntos)

	for datos in _cfg["items"]:
		_soltar_item(Vector2(datos[0], datos[1]), datos[2])
	for datos in _cfg.get("barriles", []):
		_crear_barril(Vector2(datos[0], datos[1]))

	hud.fundido(false, 0.6)
	Musica.tocar(_cfg.get("musica", ""))
	hud.mensaje(_cfg["nombre"], 1.4)
	hud.submensaje(_cfg["subtitulo"], 1.6)


## Crea al jugador 1 (y al 2) con su personaje, su vida y su rabia del nivel anterior
func _crear_jugadores() -> void:
	puntos = Juego.puntos
	for i in Juego.personajes.size():
		var j := ESCENA_JUGADOR.instantiate() as Luchador
		j.set("personaje", Juego.personajes[i])
		j.set("numero", i + 1)
		j.position = Vector2(55.0 - i * 22.0, 106.0 + i * 16.0)
		mundo.add_child(j)
		j.vida = Juego.vidas[i]
		j.set("rabia", Juego.rabias[i])
		j.connect("puntos_extra", _sumar_puntos)
		j.connect("golpe_acertado", _al_acertar)
		j.connect("especial_usado", _al_usar_especial)
		j.connect("item_agarrado", _texto_flotante)
		j.murio.connect(_al_morir_jugador)
		_conectar_efectos(j)
		jugadores.append(j)
	jugador = jugadores[0]
	# en 2 jugadores el que cayó en el nivel anterior vuelve con VIDA_AL_VOLVER (lo hace Juego)


func _vivos_jugadores() -> Array[Luchador]:
	var lista: Array[Luchador] = []
	for j in jugadores:
		if j.estado != Luchador.Estado.MUERTO:
			lista.append(j)
	return lista


func _cargar_escenario() -> void:
	_cfg = Juego.config()
	_oleadas = _cfg["oleadas"]
	fondo.texture = load(_cfg["fondo"])
	ancho_nivel = fondo.texture.get_width()
	# El piso por donde se camina depende de cada imagen de fondo
	Luchador.piso_arriba = _cfg["piso_arriba"]
	Luchador.piso_abajo = _cfg["piso_abajo"]


func _process(delta: float) -> void:
	# --- Cámara: solo avanza, nunca vuelve para atrás ---
	if fase == Fase.AVANZANDO:
		# en 2 jugadores la cámara sigue al promedio (y nadie puede salirse de la pantalla)
		var vivos := _vivos_jugadores()
		var x_medio := 0.0
		for j in vivos:
			x_medio += j.position.x / vivos.size()
		var objetivo := clampf(x_medio + 20.0, MITAD_PANTALLA, ancho_nivel - MITAD_PANTALLA)
		_camara_x = maxf(_camara_x, objetivo)
		_revisar_oleada()
	_camara_suave = lerpf(_camara_suave, _camara_x, 1.0 - exp(-6.0 * delta))
	# La cámara va en píxeles enteros: así el pixel art no "tiembla" al avanzar
	camara.position.x = roundf(_camara_suave)

	# --- Temblor de pantalla ---
	if _temblor > 0.0:
		_temblor = maxf(_temblor - delta, 0.0)
		camara.offset = (Vector2(randf_range(-2, 2), randf_range(-1, 1)) * (_temblor / 0.3)).round()
	else:
		camara.offset = Vector2.ZERO

	# --- Los jugadores no pueden salirse de la pantalla ---
	var izq := camara.position.x - MITAD_PANTALLA + 8.0
	var der := camara.position.x + MITAD_PANTALLA - 8.0
	for j in jugadores:
		j.position.x = clampf(j.position.x, izq, der)


func _unhandled_input(event: InputEvent) -> void:
	if fase == Fase.FIN and _pide_continuar(event):
		if get_meta("gano", false):
			get_tree().change_scene_to_file(MENU)
		else:
			Juego.reintentar_nivel()
			get_tree().reload_current_scene()
	elif event.is_action_pressed("pausa"):
		get_tree().change_scene_to_file(MENU)


func _pide_continuar(event: InputEvent) -> bool:
	if not get_meta("puede_reiniciar", false):
		return false
	if event is InputEventScreenTouch and event.pressed:
		return true
	return event.is_action_pressed("ui_accept") or event.is_action_pressed("atacar") \
		or event.is_action_pressed("atacar_2")


# ---------- Oleadas ----------

func _revisar_oleada() -> void:
	if _oleada >= _oleadas.size():
		return
	var o: Dictionary = _oleadas[_oleada]
	var x_max := -1.0
	for j in _vivos_jugadores():
		x_max = maxf(x_max, j.position.x)
	if x_max < o["x"]:
		return
	fase = Fase.PELEANDO
	hud.mostrar_flecha(false)
	if o.has("mensaje"):
		hud.mensaje(o["mensaje"], 1.6)
	if o.has("sub"):
		hud.submensaje(o["sub"], 1.8)
	for datos in o["enemigos"]:
		if TIPOS[datos[0]].get("es_jefe", false) or TIPOS[datos[0]].get("mini_jefe", false):
			Sonido.tocar("jefe", 0.0, 0.0)
	var lista: Array = o["enemigos"]
	_por_aparecer = lista.size()
	for i in lista.size():
		var tipo: String = lista[i][0]
		var lado: float = lista[i][1]
		var t := get_tree().create_timer(0.5 * i)
		t.timeout.connect(_crear_enemigo.bind(tipo, lado))
	_oleada += 1


func _crear_enemigo(tipo: String, lado: float) -> Luchador:
	if fase == Fase.FIN or fase == Fase.SALIENDO:
		return null
	var datos: Dictionary = TIPOS[tipo]
	var e: Luchador
	if datos.has("script"):
		# los jefes: mismo armado que un enemigo, con su propio script
		var n := Node2D.new()
		n.set_script(load(datos["script"]))
		var spr := AnimatedSprite2D.new()
		spr.name = "Sprite"
		spr.offset = EnemigoFrames.OFFSET
		n.add_child(spr)
		e = n as Luchador
	else:
		e = ESCENA_ENEMIGO.instantiate() as Luchador
	for clave: String in datos:
		if clave == "personajes":
			e.set("personaje", (datos[clave] as Array).pick_random())
		elif clave != "script":
			e.set(clave, datos[clave])
	if Juego.dos_jugadores():
		var extra := Juego.VIDA_JEFES_2J if datos.get("es_jefe", false) else Juego.VIDA_ENEMIGOS_2J
		e.vida_max = int(e.vida_max * extra)
	e.position = Vector2(_camara_x + lado * (MITAD_PANTALLA + 15.0),
		randf_range(Luchador.piso_arriba + 3.0, Luchador.piso_abajo - 3.0))
	mundo.add_child(e)
	e.murio.connect(_al_morir_enemigo)
	_conectar_efectos(e)
	_vivos += 1
	_por_aparecer -= 1
	if e.get("es_jefe") or e.get("mini_jefe"):
		_con_barra.append(e)
		e.vida_cambio.connect(func(_v: int, _m: int) -> void: _actualizar_barra())
		_actualizar_barra()
	return e


## Una sola barra para todos los jefes en pantalla (el dúo la comparte: "RIVADAVIA Y ROSAS")
func _actualizar_barra() -> void:
	if _con_barra.is_empty():
		hud.ocultar_jefe()
		return
	var vida := 0
	var maximo := 0
	var nombres: Array[String] = []
	for e in _con_barra:
		if not is_instance_valid(e):
			continue
		vida += maxi(e.vida, 0)
		maximo += e.vida_max
		nombres.append(e.get("nombre"))
	var nombre := " Y ".join(nombres)
	if nombres.size() > 1 and not Juego.dos_jugadores():
		nombre = "EL DUO"  # en 1 jugador la barra va arriba y no entra el nombre largo
	hud.mostrar_jefe(nombre, vida, maxi(maximo, 1))


func _sumar_puntos(cantidad: int) -> void:
	puntos += cantidad
	hud.actualizar_puntos(puntos)


func _al_morir_enemigo(e: Luchador) -> void:
	_vivos -= 1
	_sumar_puntos(int(e.get("puntos")))
	_efecto_piso(e.global_position, true, 1.6)  # cae al piso y levanta polvo
	if e.get("mini_jefe"):
		_con_barra.erase(e)
		_actualizar_barra()
	if e.get("es_jefe"):
		_actualizar_barra()
		for otro in _con_barra:
			if is_instance_valid(otro) and otro.estado != Luchador.Estado.MUERTO:
				return  # el dúo: falta el otro
		_jefe_derrotado()
		return
	if randf() < float(e.get("prob_item")):
		_soltar_item(e.position, _item_al_azar())
	if _vivos <= 0 and _por_aparecer <= 0 and fase == Fase.PELEANDO:
		if _oleada >= _oleadas.size():
			_nivel_completo()
		else:
			fase = Fase.AVANZANDO
			hud.mostrar_flecha(true)
			Sonido.tocar("adelante", 0.0, 0.0)


## Los enemigos sueltan sobre todo VINO (para cargar la rabia)
func _item_al_azar() -> Item.Tipo:
	var r := randf()
	if r < 0.55:
		return Item.Tipo.VINO
	if r < 0.85:
		return Item.Tipo.ALBAHACA
	return Item.Tipo.CHORIPAN


## Los barriles sueltan COMIDA (para curarse)
func _comida_al_azar() -> Item.Tipo:
	var r := randf()
	if r < 0.5:
		return Item.Tipo.ALBAHACA
	if r < 0.9:
		return Item.Tipo.CHORIPAN
	return Item.Tipo.HARINA


# ---------- Barriles ----------

func _crear_barril(pos: Vector2) -> void:
	var b := ESCENA_BARRIL.instantiate() as Luchador
	b.position = Vector2(pos.x, clampf(pos.y, Luchador.piso_arriba, Luchador.piso_abajo))
	mundo.add_child(b)
	b.impacto.connect(func(donde: Vector2, _fuerte: bool) -> void:
		_particulas(donde + Vector2(0, -8), 8, COLORES_MADERA, 35.0, 110.0, 0.45, 160.0))
	b.murio.connect(_al_romper_barril)


func _al_romper_barril(b: Luchador) -> void:
	_sumar_puntos(int(b.get("puntos")))
	_particulas(b.global_position + Vector2(0, -8), 22, COLORES_MADERA, 60.0, 130.0, 0.7, 200.0)
	_efecto_piso(b.global_position, true, 1.0)
	_temblor = maxf(_temblor, 0.12)
	var fijo: int = b.get("item_fijo")
	var tipo: Item.Tipo = _comida_al_azar()
	if fijo >= 0:
		tipo = fijo as Item.Tipo
	_soltar_item(b.position + Vector2(0, 1), tipo)


func _soltar_item(pos: Vector2, tipo: Item.Tipo) -> void:
	var it := ESCENA_ITEM.instantiate() as Item
	it.tipo = tipo
	it.position = Vector2(pos.x, clampf(pos.y, Luchador.piso_arriba, Luchador.piso_abajo))
	mundo.add_child.call_deferred(it)


# ---------- Efectos según el piso ----------

func _conectar_efectos(l: Luchador) -> void:
	l.paso.connect(func(donde: Vector2, corriendo: bool) -> void:
		_efecto_piso(donde, false, 1.4 if corriendo else 0.7))
	l.impacto.connect(func(donde: Vector2, fuerte: bool) -> void:
		_efecto_golpe(donde, fuerte))
	if l.has_signal("fogonazo"):
		l.connect("fogonazo", _efecto_fogonazo)


## Fogonazo y humo del fusil
func _efecto_fogonazo(donde: Vector2, direccion: float) -> void:
	_particulas(donde, 6, [Color.WHITE, Color("#ffe9a0"), Color("#ffb347")], 40.0, 0.0, 0.12, 50.0)
	var humo := [Color(0.85, 0.85, 0.85, 0.8), Color(0.7, 0.7, 0.72, 0.7)]
	_particulas(donde + Vector2(direccion * 2.0, 0), 8, humo, 14.0, -12.0, 0.6, 120.0)


## Polvo en los pies: el color sale de la zona de piso (vereda, asfalto, baldosas, tierra...)
func _efecto_piso(donde: Vector2, fuerte: bool, intensidad: float) -> void:
	var zona := Juego.zona_de_piso(donde.y)
	var cantidad := int((14 if fuerte else 5) * intensidad)
	_particulas(donde + Vector2(0, -1), maxi(cantidad, 3), zona["polvo"],
		20.0 * intensidad, 35.0, 0.45 if not fuerte else 0.7, 160.0)


## Lo que salta cuando un golpe entra (en la Chaya: harina y albahaca)
func _efecto_golpe(donde: Vector2, fuerte: bool) -> void:
	var zona := Juego.zona_de_piso(donde.y)
	# Chispa blanca donde pega la lanza
	_particulas(donde + Vector2(0, -18), 10 if fuerte else 6, [Color.WHITE, Color("#ffe9a0"), Color("#ffd04a")],
		85.0, 0.0, 0.16, 360.0)
	_particulas(donde + Vector2(0, -19), 24 if fuerte else 12, zona["golpe"],
		45.0 if fuerte else 30.0, 60.0, 0.5, 180.0)
	if fuerte:
		_efecto_piso(donde, true, 1.0)


func _particulas(pos: Vector2, cantidad: int, colores: Array, velocidad: float,
		gravedad: float, duracion: float, apertura: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = cantidad
	p.lifetime = duracion
	p.direction = Vector2.UP
	p.spread = apertura * 0.5
	p.initial_velocity_min = velocidad * 0.4
	p.initial_velocity_max = velocidad
	p.gravity = Vector2(0, gravedad)
	p.damping_min = 10.0
	p.damping_max = 30.0
	# grilla de 16px: partículas de 1 y 2 píxeles
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var paleta := Gradient.new()
	paleta.colors = PackedColorArray(colores)
	paleta.offsets = PackedFloat32Array(_offsets(colores.size()))
	paleta.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = paleta
	var desvanecer := Gradient.new()
	desvanecer.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = desvanecer
	p.z_index = 1
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _offsets(n: int) -> Array:
	var o := []
	for i in n:
		o.append(float(i) / n)
	return o


# ---------- Sensación de golpe ("game feel") ----------

func _al_acertar(fuerte: bool) -> void:
	# Congelar el juego unos milisegundos hace que el golpe "pese"
	_congelar(0.09 if fuerte else 0.04)
	if fuerte:
		_temblor = 0.25


func _al_usar_especial(quien: Node2D) -> void:
	_temblor = 0.4
	var datos: Dictionary = quien.get("datos")
	hud.mensaje(datos["grito"], 0.8)
	if datos["ulti"] == "remolino":
		# Explosión de lo que haya en el piso alrededor del Chacho
		for i in 8:
			var ang := TAU * i / 8.0
			_efecto_golpe(quien.global_position + Vector2(cos(ang) * 25.0, sin(ang) * 9.0 + 15.0), false)
	else:
		# Polvareda detrás de Quiroga al arrancar la embestida
		_efecto_piso(quien.global_position, true, 2.0)


func _congelar(segundos: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(segundos, true, false, true).timeout
	Engine.time_scale = 1.0


func _texto_flotante(texto: String, color: Color, donde: Vector2) -> void:
	var l := Label.new()
	l.text = texto
	l.label_settings = Fuente.ajustes(8, color)
	# que no se salga de la pantalla (240 px de ancho)
	var ancho := Fuente.fuente().get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4.0
	var izq := camara.position.x - MITAD_PANTALLA + 2.0
	var der := camara.position.x + MITAD_PANTALLA - 2.0 - ancho
	l.position = Vector2(clampf(donde.x - ancho / 2.0, izq, der), donde.y).round()
	l.size = Vector2(ancho, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 100
	add_child(l)
	var t := create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 11.0, 0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	t.chain().tween_callback(l.queue_free)


# ---------- API para los jefes (scripts/jefe*.gd y ataques_jefes.gd) ----------

## Borde izquierdo y derecho de lo que se ve (x del mundo)
func limites() -> Vector2:
	return Vector2(camara.position.x - MITAD_PANTALLA, camara.position.x + MITAD_PANTALLA)


func temblar(segundos: float) -> void:
	_temblor = maxf(_temblor, segundos)


func polvo(donde: Vector2, intensidad := 1.0) -> void:
	_efecto_piso(donde, true, intensidad)


func chispas(donde: Vector2, colores: Array, cantidad := 12) -> void:
	_particulas(donde, cantidad, colores, 55.0, 120.0, 0.5, 200.0)


func texto(t: String, color: Color, donde: Vector2) -> void:
	_texto_flotante(t, color, donde)


func mensaje(t: String, sub := "", duracion := 1.4) -> void:
	hud.mensaje(t, duracion)
	if sub != "":
		hud.submensaje(sub, duracion + 0.2)


## Hace aparecer un enemigo desde un costado (los guardaespaldas del jefe final)
func aparecer(tipo: String, lado: float) -> Luchador:
	_por_aparecer += 1
	return _crear_enemigo(tipo, lado)


func congelar(segundos: float) -> void:
	_congelar(segundos)


## Cayó el (o los) jefe(s): cámara lenta, se van los que quedan y se pasa de nivel (o se gana)
func _jefe_derrotado() -> void:
	fase = Fase.SALIENDO
	hud.mostrar_flecha(false)
	_temblor = 0.6
	Engine.time_scale = 0.35
	await get_tree().create_timer(0.9, true, false, true).timeout
	Engine.time_scale = 1.0
	for n in get_tree().get_nodes_in_group("proyectiles"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("enemigos"):
		var e := n as Luchador
		if e.estado != Luchador.Estado.MUERTO:
			e.morir()
	_con_barra.clear()
	hud.ocultar_jefe()
	if Juego.es_ultimo_nivel():
		_victoria()
	else:
		_nivel_completo()


# ---------- Fin del nivel / del juego ----------

func _nivel_completo() -> void:
	fase = Fase.SALIENDO
	hud.mensaje("¡NIVEL COMPLETO!", 1.8)
	Musica.parar(0.4)
	Sonido.tocar("nivel_completo", 0.0, 0.0)
	await get_tree().create_timer(2.2).timeout
	hud.fundido(true, 0.6)
	await get_tree().create_timer(0.7).timeout
	var vidas := []
	var rabias := []
	for j in jugadores:
		vidas.append(j.vida)
		rabias.append(j.get("rabia"))
	Juego.pasar_de_nivel(puntos, vidas, rabias)
	get_tree().reload_current_scene()


func _al_morir_jugador(j: Luchador) -> void:
	if not _vivos_jugadores().is_empty():
		# de a 2: el otro sigue; el que cayó vuelve en el nivel siguiente
		hud.mensaje("¡CAYO %s!" % j.get("datos")["nombre"], 1.2)
		return
	if fase == Fase.FIN or fase == Fase.SALIENDO:
		return
	fase = Fase.FIN
	hud.mostrar_flecha(false)
	Musica.parar(1.0)
	await get_tree().create_timer(1.4).timeout
	Sonido.tocar("game_over", 0.0, 0.0)
	var texto := "LOS CAUDILLOS CAYERON... PERO LA MONTONERA SIGUE." if jugadores.size() > 1 \
		else "%s CAYO... PERO LA MONTONERA SIGUE." % ("EL CHACHO" if jugador.get("personaje") == "chacho" else "QUIROGA")
	hud.mostrar_fin("GAME OVER", texto, puntos,
		"ENTER O TOCAR: REINTENTAR")
	_habilitar_reinicio()


func _victoria() -> void:
	fase = Fase.FIN
	set_meta("gano", true)
	hud.ocultar_jefe()
	hud.mensaje("¡VICTORIA!", 1.5)
	Musica.parar(0.4)
	Sonido.tocar("victoria", 0.0, 0.0)
	_temblor = 0.5
	await get_tree().create_timer(2.0).timeout
	var texto := "EL CHACHO Y QUIROGA DEFENDIERON LA RIOJA." if jugadores.size() > 1 \
		else "%s DEFENDIO LA RIOJA." % ("EL CHACHO" if jugador.get("personaje") == "chacho" else "QUIROGA")
	hud.mostrar_fin("¡VICTORIA!", texto, puntos,
		"ENTER O TOCAR: VOLVER AL MENU")
	_habilitar_reinicio()


func _habilitar_reinicio() -> void:
	$ControlesTactiles.visible = false
	await get_tree().create_timer(0.6).timeout
	set_meta("puede_reiniciar", true)
