extends Control
## Menú principal de Chacho Attack.
## El menú se dibuja a 480x270. El juego usa 240x135 (grilla de 16px, x6): mientras el
## menú está abierto se cambia el tamaño del viewport a 480x270 y al salir se restaura
## el original. Así el arte del menú tiene el doble de detalle que el juego.
## Funciona con teclado / joystick (ui_up, ui_down, ui_accept, ui_cancel), mouse y pantalla táctil.

# ---------------------------------------------------------------- AJUSTAR ACÁ
## Escena que se abre al elegir JUGAR.
const ESCENA_JUEGO := "res://escenas/intro.tscn"   # la intro (rotonda) y después el nivel 1

## v7.2: menú corto de 3 opciones. JUGAR abre el submenú (1 o 2 jugadores) y después se elige personaje.
const OPCIONES := ["JUGAR", "CONTROLES", "CREDITOS"]
const SUBMENU_JUGAR := ["1 JUGADOR", "2 JUGADORES", "VOLVER"]

## Personajes elegibles: [id, nombre en pantalla, arma, ulti]
const ELEGIBLES := [
	["chacho", "EL CHACHO", "LANZA", "RABIA RIOJANA"],
	["quiroga", "QUIROGA", "SABLE", "TIGRE DE LOS LLANOS"],
]

## Texto de la pantalla de créditos (Press Start 2P no tiene tildes lindas: escribí sin tildes).
const TEXTO_CREDITOS := "CHACHO ATTACK\n\nGAME JAM - LA RIOJA 2026\n\nEQUIPO:\nNOMBRE 1\nNOMBRE 2\nNOMBRE 3\n\nMUSICA (VERSIONES 8 BIT):\nCARNAVAL DE LA RIOJA - EL CAMION DE GERMAN\nCUANDO ERA CHANGO - CHAYITA DEL VIDALERO"

## Texto de la pantalla CONTROLES (si cambian teclas en scripts/entradas.gd, cambien esto también)
const TEXTO_CONTROLES := "CONTROLES\n\n1 JUGADOR\nMOVER: WASD O FLECHAS   ATACAR (COMBO): J\nBLOQUEAR: K   CORRER: SHIFT   RABIA: L\n\n2 JUGADORES\n1P: WASD  ATACA C  BLOQUEA V  RABIA B  CORRE SHIFT IZQ\n2P: FLECHAS  ATACA K  BLOQUEA L  RABIA Ñ  CORRE SHIFT DER\n(2P TAMBIEN: TECLADO NUMERICO 1 2 3 0)\n\nJOYSTICK: X ATACA  B BLOQUEA  Y RABIA  RB CORRE\nESC: VOLVER AL MENU"
# ----------------------------------------------------------------------------

const DIR := "res://menu/"
const TAM_MENU := Vector2i(480, 270)
const COLOR_TEXTO := Color("ffb347")
const COLOR_ELEGIDO := Color("fff4c2")
const COLOR_BORDE := Color("2a0d12")
const COLOR_CAJA := Color(0.31, 0.32, 0.38, 0.92)
const COLOR_CAJA_BORDE := Color("f5c542")

## v7: portada nueva del equipo (fondo_menu.png). Las opciones van abajo al centro,
## sobre la camisa del Chacho, para no tapar ninguna cara.
const OPC_X := 152      # x donde empiezan las opciones
const OPC_Y := 206      # y de la primera opción
const OPC_PASO := 18    # separación entre opciones
## El logo ya viene dibujado en la portada. logo.png es el mismo logo recortado (210x105),
## que entra "estampándose" justo encima de donde está en la imagen.
const LOGO_POS := Vector2(6, 12)

var fuente: FontFile
var ajustes_normal: LabelSettings
var ajustes_elegido: LabelSettings
var ajustes_chico: LabelSettings

var etiquetas: Array[Label] = []
var _opciones: Array = OPCIONES   # las que se ven ahora (menú principal o submenú JUGAR)
var elegido := 0
var listo := false          # false durante la intro y al salir
var t := 0.0

var raiz: Control           # todo lo que tiembla
var logo: TextureRect
var fondo: TextureRect
var caja_opciones: Panel
var flash: ColorRect
var cursor: TextureRect
var capa_brillos: Control
var panel_info: ColorRect
var texto_info: Label
var fundido: ColorRect
var tam_original := Vector2i.ZERO

# Pantalla para elegir personaje
var eleccion: ColorRect
var _dos_jugadores := false
var _elegido_1p := 0   # qué personaje tiene el jugador 1 (el 2 tiene el otro)
var _tarjetas: Array[Control] = []
var _etiquetas_jugador: Array[Label] = []

# brillos que titilan sobre el fondo (zonas libres de la portada): posición y fase
var brillos := [
	Vector2(373, 18), Vector2(46, 55), Vector2(23, 141), Vector2(226, 10),
	Vector2(468, 150), Vector2(110, 120), Vector2(176, 132), Vector2(306, 40),
]


func _enter_tree() -> void:
	var ventana := get_tree().root
	tam_original = ventana.content_scale_size
	ventana.content_scale_size = TAM_MENU
	# el menú es una ilustración: puede escalar a x2,5 (si la ventana es 1200x675) sin bordes negros
	ventana.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL


func _exit_tree() -> void:
	# al pasar al juego (o al cerrar) vuelve la resolución base del proyecto
	get_tree().root.content_scale_size = tam_original
	get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preparar_fuente()

	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	fondo = TextureRect.new()
	# durante la intro se ve la portada sin logo; cuando el logo "cae" se cambia por la original
	fondo.texture = load(DIR + "fondo_menu_sin_logo.png")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(fondo)

	capa_brillos = Control.new()
	capa_brillos.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa_brillos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_brillos.draw.connect(_dibujar_brillos)
	raiz.add_child(capa_brillos)

	logo = TextureRect.new()
	logo.texture = load(DIR + "logo.png")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # se agranda en la intro: que no se vea serruchado
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(logo)
	logo.size = logo.texture.get_size()
	logo.pivot_offset = logo.size / 2.0

	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(flash)

	# caja oscura detrás de las opciones (sobre la camisa del Chacho), mismo estilo que la de ayuda
	caja_opciones = Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.05, 0.11, 0.78)
	estilo.border_color = COLOR_CAJA_BORDE
	estilo.set_border_width_all(2)
	caja_opciones.add_theme_stylebox_override("panel", estilo)
	caja_opciones.position = Vector2(OPC_X - 30, OPC_Y - 7)
	caja_opciones.size = Vector2(218, OPC_PASO * OPCIONES.size() + 10)
	caja_opciones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(caja_opciones)

	for i in OPCIONES.size():
		var et := Label.new()
		et.text = OPCIONES[i]
		et.label_settings = ajustes_normal
		et.position = Vector2(OPC_X, OPC_Y + i * OPC_PASO)
		et.mouse_filter = Control.MOUSE_FILTER_STOP
		et.mouse_entered.connect(_elegir.bind(i))
		et.gui_input.connect(_click_opcion.bind(i))
		raiz.add_child(et)
		etiquetas.append(et)

	cursor = TextureRect.new()
	cursor.texture = load(DIR + "cursor_choripan.png")
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(cursor)

	_crear_caja_ayuda()
	_crear_eleccion()
	_crear_panel_info()

	fundido = ColorRect.new()
	fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundido.color = Color.BLACK
	fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundido)

	_elegir(0)
	_intro()
	Musica.tocar("menu", 1.2)


# ---------------------------------------------------------------- armado
func _preparar_fuente() -> void:
	fuente = load(DIR + "PressStart2P-Regular.ttf")
	fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fuente.hinting = TextServer.HINTING_NONE
	fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

	ajustes_normal = LabelSettings.new()
	ajustes_normal.font = fuente
	ajustes_normal.font_size = 16
	ajustes_normal.font_color = COLOR_TEXTO
	ajustes_normal.outline_size = 4
	ajustes_normal.outline_color = COLOR_BORDE
	ajustes_normal.shadow_size = 4
	ajustes_normal.shadow_color = COLOR_BORDE
	ajustes_normal.shadow_offset = Vector2(2, 2)

	ajustes_elegido = ajustes_normal.duplicate()
	ajustes_elegido.font_color = COLOR_ELEGIDO

	ajustes_chico = ajustes_normal.duplicate()
	ajustes_chico.font_size = 8
	ajustes_chico.outline_size = 2
	ajustes_chico.shadow_size = 2
	ajustes_chico.shadow_offset = Vector2(1, 1)


func _crear_caja_ayuda() -> void:
	var caja := Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_CAJA
	estilo.border_color = COLOR_CAJA_BORDE
	estilo.set_border_width_all(2)
	caja.add_theme_stylebox_override("panel", estilo)
	caja.position = Vector2(4, 243)
	caja.size = Vector2(118, 23)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(caja)

	var et := Label.new()
	et.text = "ENTER O TOCAR"
	et.label_settings = ajustes_chico
	et.position = Vector2(8, 7)
	caja.add_child(et)


func _crear_panel_info() -> void:
	panel_info = ColorRect.new()
	panel_info.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_info.color = Color(0.06, 0.04, 0.1, 0.88)
	panel_info.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_info.gui_input.connect(_click_panel)
	panel_info.visible = false
	add_child(panel_info)

	texto_info = Label.new()
	texto_info.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto_info.label_settings = ajustes_chico
	panel_info.add_child(texto_info)


## Pantalla "ELEGI TU CAUDILLO": dos tarjetas con el personaje animado
func _crear_eleccion() -> void:
	eleccion = ColorRect.new()
	eleccion.set_anchors_preset(Control.PRESET_FULL_RECT)
	eleccion.color = Color(0.06, 0.04, 0.1, 0.95)
	eleccion.mouse_filter = Control.MOUSE_FILTER_STOP
	eleccion.visible = false
	add_child(eleccion)
	var titulo := Label.new()
	titulo.text = "ELEGI TU CAUDILLO"
	titulo.label_settings = ajustes_elegido
	titulo.position = Vector2(0, 14)
	titulo.size = Vector2(480, 20)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eleccion.add_child(titulo)
	for i in ELEGIBLES.size():
		var d: Array = ELEGIBLES[i]
		var t := Control.new()
		t.position = Vector2(22 + i * 228, 44)
		t.size = Vector2(208, 190)
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		t.gui_input.connect(_click_tarjeta.bind(i))
		t.draw.connect(_dibujar_tarjeta.bind(t, i))
		eleccion.add_child(t)
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = Personajes.frames(d[0])
		spr.offset = Personajes.datos(d[0])["offset"]
		spr.scale = Vector2(3, 3)
		spr.position = Vector2(104, 128)
		spr.play(&"quieto")
		t.add_child(spr)
		var nombre := _texto(d[1], ajustes_normal, Vector2(0, 136), 208)
		t.add_child(nombre)
		t.add_child(_texto("ARMA: " + d[2], ajustes_chico, Vector2(0, 158), 208))
		t.add_child(_texto("ULTI: " + d[3], ajustes_chico, Vector2(0, 170), 208))
		var etiqueta := _texto("1P", ajustes_elegido, Vector2(0, 8), 208)
		t.add_child(etiqueta)
		_tarjetas.append(t)
		_etiquetas_jugador.append(etiqueta)
	var ayuda := _texto("IZQ / DER PARA CAMBIAR   ENTER PARA EMPEZAR   ESC VOLVER", ajustes_chico,
		Vector2(0, 250), 480)
	eleccion.add_child(ayuda)


func _texto(txt: String, ajustes: LabelSettings, pos: Vector2, ancho: float) -> Label:
	var l := Label.new()
	l.text = txt
	l.label_settings = ajustes
	l.position = pos
	l.size = Vector2(ancho, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _abrir_eleccion(dos: bool) -> void:
	_dos_jugadores = dos
	eleccion.visible = true
	eleccion.modulate.a = 0.0
	create_tween().tween_property(eleccion, "modulate:a", 1.0, 0.12)
	_actualizar_eleccion()


func _actualizar_eleccion() -> void:
	for i in _tarjetas.size():
		var es_1p := i == _elegido_1p
		_etiquetas_jugador[i].visible = es_1p or _dos_jugadores
		_etiquetas_jugador[i].text = "1P" if es_1p else "2P"
		_etiquetas_jugador[i].label_settings = ajustes_elegido if es_1p else ajustes_normal
		var spr := _tarjetas[i].get_child(0) as AnimatedSprite2D
		var activo := es_1p or _dos_jugadores
		spr.modulate = Color.WHITE if activo else Color(0.45, 0.45, 0.5)
		spr.play(&"caminar" if es_1p else &"quieto")
		_tarjetas[i].queue_redraw()


func _dibujar_tarjeta(t: Control, i: int) -> void:
	var es_1p := i == _elegido_1p
	var activo := es_1p or _dos_jugadores
	t.draw_rect(Rect2(Vector2.ZERO, t.size), Color(0.18, 0.12, 0.2, 0.85))
	var borde := COLOR_CAJA_BORDE if es_1p else (Color("9fd8ff") if activo else Color(0.4, 0.4, 0.45))
	t.draw_rect(Rect2(Vector2.ZERO, t.size), borde, false, 2.0)


func _click_tarjeta(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if i == _elegido_1p:
			_confirmar_eleccion()
		else:
			_mover_eleccion()
		accept_event()


func _mover_eleccion() -> void:
	_elegido_1p = 1 - _elegido_1p
	Sonido.tocar("menu_mover", 0.0, 0.0)
	_actualizar_eleccion()


func _confirmar_eleccion() -> void:
	var lista := [ELEGIBLES[_elegido_1p][0]]
	if _dos_jugadores:
		lista.append(ELEGIBLES[1 - _elegido_1p][0])
	Sonido.tocar("menu_aceptar", 0.0, 0.0)
	_empezar(lista)


# ---------------------------------------------------------------- animación
func _intro() -> void:
	listo = false
	# el logo arranca grande y transparente y se "estampa" en su lugar
	logo.position = LOGO_POS
	logo.scale = Vector2(2.6, 2.6)
	logo.modulate.a = 0.0
	for i in etiquetas.size():
		etiquetas[i].modulate.a = 0.0
	cursor.modulate.a = 0.0
	caja_opciones.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(fundido, "color:a", 0.0, 0.35)
	tw.tween_property(logo, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(logo, "modulate:a", 1.0, 0.2)
	tw.tween_callback(_estampar)
	tw.tween_property(caja_opciones, "modulate:a", 1.0, 0.12)
	for i in etiquetas.size():
		tw.tween_property(etiquetas[i], "modulate:a", 1.0, 0.08)
	tw.tween_property(cursor, "modulate:a", 1.0, 0.1)
	tw.tween_callback(func(): listo = true)


## El golpe del logo: destello blanco, se cambia al fondo original (que ya trae el logo) y tiembla
func _estampar() -> void:
	fondo.texture = load(DIR + "fondo_menu.png")
	logo.visible = false
	flash.color = Color(1, 1, 1, 0.75)
	create_tween().tween_property(flash, "color:a", 0.0, 0.3)
	_temblar(4.0, 0.25)
	Sonido.tocar("logo", 0.0, 0.0)


func _temblar(fuerza: float, duracion: float) -> void:
	var tw := create_tween()
	var pasos := int(duracion / 0.03)
	for k in pasos:
		var f := fuerza * (1.0 - float(k) / pasos)
		tw.tween_property(raiz, "position", Vector2(randf_range(-f, f), randf_range(-f, f)).round(), 0.03)
	tw.tween_property(raiz, "position", Vector2.ZERO, 0.03)


func _process(delta: float) -> void:
	t += delta
	var et := etiquetas[elegido]
	var bob := roundf(sin(t * 9.0) * 2.0)
	cursor.position = Vector2(OPC_X - cursor.size.x - 4 + bob, et.position.y + roundf((et.size.y - cursor.size.y) / 2.0))
	capa_brillos.queue_redraw()


func _dibujar_brillos() -> void:
	# brillos pixelados de 4 puntas que titilan
	for i in brillos.size():
		var fase := sin(t * 2.4 + i * 1.7)
		if fase < 0.2:
			continue
		var p: Vector2 = brillos[i]
		var largo := 1 + int(fase * 3.0)
		var c := Color(1, 1, 1, clampf(fase, 0.0, 1.0))
		capa_brillos.draw_rect(Rect2(p.x - largo, p.y, largo * 2 + 1, 1), c)
		capa_brillos.draw_rect(Rect2(p.x, p.y - largo, 1, largo * 2 + 1), c)


# ---------------------------------------------------------------- entrada
func _unhandled_input(event: InputEvent) -> void:
	if eleccion.visible and listo:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") \
				or event.is_action_pressed("mover_izq") or event.is_action_pressed("mover_der"):
			_mover_eleccion()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("atacar"):
			_confirmar_eleccion()
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pausa"):
			eleccion.visible = false
			Sonido.tocar("menu_volver", 0.0, 0.0)
		return
	if panel_info.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_cerrar_panel()
		return
	if not listo:
		if event.is_action_pressed("ui_accept"):
			_saltear_intro()
		return
	if event.is_action_pressed("ui_down"):
		_elegir((elegido + 1) % _opciones.size())
	elif event.is_action_pressed("ui_up"):
		_elegir((elegido - 1 + _opciones.size()) % _opciones.size())
	elif event.is_action_pressed("ui_accept"):
		_activar()
	elif event.is_action_pressed("ui_cancel") and _opciones != OPCIONES:
		Sonido.tocar("menu_volver", 0.0, 0.0)
		_mostrar_opciones(OPCIONES, 0)


func _click_opcion(event: InputEvent, i: int) -> void:
	if not listo:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_elegir(i)
		_activar()
		accept_event()


func _click_panel(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_cerrar_panel()
		accept_event()


func _saltear_intro() -> void:
	for tw in get_tree().get_processed_tweens():
		tw.custom_step(10.0)


# ---------------------------------------------------------------- acciones
func _elegir(i: int) -> void:
	if i != elegido and listo:
		_temblar(1.0, 0.06)
		Sonido.tocar("menu_mover", 0.0, 0.0)
	elegido = i
	for k in etiquetas.size():
		etiquetas[k].label_settings = ajustes_elegido if k == elegido else ajustes_normal


## Cambia lo que dicen las 3 opciones (menú principal ↔ submenú JUGAR), con un saltito
func _mostrar_opciones(lista: Array, cual: int) -> void:
	_opciones = lista
	for i in etiquetas.size():
		etiquetas[i].text = lista[i] if i < lista.size() else ""
		etiquetas[i].visible = i < lista.size()
		etiquetas[i].position.x = OPC_X + 10.0
		create_tween().tween_property(etiquetas[i], "position:x", float(OPC_X), 0.08 + i * 0.03) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elegido = cual
	for k in etiquetas.size():
		etiquetas[k].label_settings = ajustes_elegido if k == elegido else ajustes_normal


func _activar() -> void:
	match _opciones[elegido]:
		"JUGAR":
			Sonido.tocar("menu_aceptar", 0.0, 0.0)
			_mostrar_opciones(SUBMENU_JUGAR, 0)
			return
		"VOLVER":
			Sonido.tocar("menu_volver", 0.0, 0.0)
			_mostrar_opciones(OPCIONES, 0)
			return
	Sonido.tocar("menu_aceptar", 0.0, 0.0)
	match _opciones[elegido]:
		"1 JUGADOR":
			_abrir_eleccion(false)
		"2 JUGADORES":
			_abrir_eleccion(true)
		"CONTROLES":
			_abrir_panel(TEXTO_CONTROLES + "\n\n\nENTER O TOCAR PARA VOLVER")
		"CREDITOS":
			_abrir_panel(TEXTO_CREDITOS + "\n\n\nENTER O TOCAR PARA VOLVER")


func _empezar(personajes: Array) -> void:
	if not ResourceLoader.exists(ESCENA_JUEGO):
		_abrir_panel("NO ENCUENTRO LA ESCENA:\n\n" + ESCENA_JUEGO + "\n\nCAMBIALA EN menu.gd")
		return
	listo = false
	Musica.parar(0.5)
	Entradas.configurar(personajes.size() > 1)
	Juego.nueva_partida(personajes)  # vida, puntos y rabia de cero, y arranca en el nivel 1
	_temblar(5.0, 0.3)
	var tw := create_tween()
	fundido.color = Color(1, 1, 1, 0.9)       # flash blanco
	tw.tween_property(fundido, "color", Color(0, 0, 0, 0), 0.12)
	tw.tween_property(fundido, "color", Color(0, 0, 0, 1), 0.45)
	tw.tween_callback(func(): get_tree().change_scene_to_file(ESCENA_JUEGO))


func _abrir_panel(texto: String) -> void:
	texto_info.text = texto
	panel_info.visible = true
	panel_info.modulate.a = 0.0
	create_tween().tween_property(panel_info, "modulate:a", 1.0, 0.12)


func _cerrar_panel() -> void:
	panel_info.visible = false
	Sonido.tocar("menu_volver", 0.0, 0.0)
