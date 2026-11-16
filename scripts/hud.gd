extends CanvasLayer
## HUD: vida y barra de RABIA de cada jugador, puntos, barra del jefe y mensajes.
## 1 jugador: panel arriba a la izquierda, puntos arriba a la derecha, jefe arriba al centro.
## 2 jugadores: un panel en cada esquina de arriba, puntos al centro y el jefe abajo.
## Pantalla de 240x135 (grilla de 16px): todo el texto va con la fuente pixel a 8 o 16 px.

const TEX_ITEMS := preload("res://sprites/items_spritesheet.png")
const ICONO_VINO := Rect2(0, 16, 16, 16)
const C_RABIA := Color("#ff8a2a")
const C_RABIA_LLENA := Color("#ff3b2a")
const C_RABIA_LUZ := Color("#ffd23a")

const C_BORDE := Color("#1a0f14")
const C_FONDO := Color("#3b1c1f")
const C_VIDA := Color("#e0463a")
const C_VIDA_LUZ := Color("#ff8a5c")
const C_DANIO := Color("#f6d9a4")
const C_TEXTO := Color("#fff1d6")
const C_DORADO := Color("#f2b84b")

const C_J2 := Color("#9fd8ff")

## Un panel por jugador: {vida, max, lenta, rabia, activa, x, numero}
var _paneles: Array[Dictionary] = []
var _dos := false
var _jefe_vida := -1.0
var _jefe_max := 1.0
var _jefe_lenta := 0.0

var _lienzo: Control
var _lbl_puntos: Label
var _lbl_mensaje: Label
var _lbl_jefe: Label
var _lbl_flecha: Label
var _fin: Control
var _tween_mensaje: Tween
var _lbl_sub: Label
var _negro: ColorRect


func _ready() -> void:
	layer = 4
	_lienzo = Control.new()
	_lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.draw.connect(_dibujar)
	add_child(_lienzo)

	_lbl_puntos = _label("000000", 8, Vector2(156, 3), C_TEXTO, Vector2(80, 10), HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl_jefe = _label("", 8, Vector2(84, 3), C_TEXTO, Vector2(100, 10), HORIZONTAL_ALIGNMENT_CENTER)
	_lbl_mensaje = _label("", 16, Vector2(4, 30), C_TEXTO, Vector2(232, 44), HORIZONTAL_ALIGNMENT_CENTER)
	_lbl_mensaje.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_mensaje.modulate.a = 0.0
	_lbl_mensaje.pivot_offset = Vector2(116, 22)
	_lbl_sub = _label("", 8, Vector2(0, 76), C_DORADO, Vector2(240, 10), HORIZONTAL_ALIGNMENT_CENTER)
	_lbl_sub.modulate.a = 0.0
	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.modulate.a = 0.0
	_lbl_flecha = _label("¡ADELANTE! ▶", 8, Vector2(116, 62), C_DORADO, Vector2(120, 10), HORIZONTAL_ALIGNMENT_RIGHT)
	_lbl_flecha.visible = false
	add_child(_negro)  # último: tapa todo cuando se funde a negro


## Lo llama el nivel con la lista de jugadores
func configurar(jugadores: Array) -> void:
	_dos = jugadores.size() > 1
	for i in jugadores.size():
		var j: Node = jugadores[i]
		var x := 1.0 if i == 0 else 159.0
		_paneles.append({"vida": float(j.vida), "max": float(j.vida_max), "lenta": float(j.vida),
			"rabia": float(j.get("rabia")), "activa": false, "x": x, "numero": i + 1})
		var nombre: String = j.get("datos")["nombre"]
		_label(nombre, 8, Vector2(x + 3, 3), C_DORADO if i == 0 else C_J2)
		j.vida_cambio.connect(actualizar_vida.bind(i))
		j.rabia_cambio.connect(actualizar_rabia.bind(i))
	if _dos:
		# puntos al centro y la barra del jefe abajo (los paneles ocupan las dos esquinas)
		_lbl_puntos.position = Vector2(84, 3)
		_lbl_puntos.size = Vector2(72, 10)
		_lbl_puntos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl_jefe.position = Vector2(0, 113)
		_lbl_jefe.size = Vector2(240, 10)


func _process(delta: float) -> void:
	for p in _paneles:
		p["lenta"] = move_toward(p["lenta"], p["vida"], 45.0 * delta)
	_jefe_lenta = move_toward(_jefe_lenta, maxf(_jefe_vida, 0.0), 90.0 * delta)
	if _lbl_flecha.visible:
		_lbl_flecha.modulate.a = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 180.0))
	_lienzo.queue_redraw()


# ---------- Lo que llama el nivel ----------

func actualizar_vida(vida: int, vida_max: int, i := 0) -> void:
	var p := _paneles[i]
	p["vida"] = float(vida)
	p["max"] = float(vida_max)
	if p["vida"] > p["lenta"]:
		p["lenta"] = p["vida"]  # al curarse, la barra sube de golpe


func actualizar_rabia(valor: float, activa: bool, i := 0) -> void:
	_paneles[i]["rabia"] = valor
	_paneles[i]["activa"] = activa


func actualizar_puntos(puntos: int) -> void:
	_lbl_puntos.text = "%06d" % puntos


func mostrar_jefe(nombre: String, vida: int, vida_max: int) -> void:
	_lbl_jefe.text = nombre
	_jefe_max = vida_max
	if _jefe_vida < 0.0:
		_jefe_lenta = vida
	_jefe_vida = vida


func ocultar_jefe() -> void:
	_jefe_vida = -1.0
	_lbl_jefe.text = ""


func mostrar_flecha(si: bool) -> void:
	_lbl_flecha.visible = si


func mensaje(texto: String, duracion := 1.6) -> void:
	_lbl_mensaje.text = texto
	if _tween_mensaje:
		_tween_mensaje.kill()
	_lbl_mensaje.modulate.a = 1.0
	_lbl_mensaje.scale = Vector2(1.25, 1.25)
	_tween_mensaje = create_tween()
	_tween_mensaje.tween_property(_lbl_mensaje, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_mensaje.tween_interval(duracion)
	_tween_mensaje.tween_property(_lbl_mensaje, "modulate:a", 0.0, 0.3)


## Texto chico debajo del mensaje grande (nombre del escenario)
func submensaje(texto: String, duracion := 1.6) -> void:
	_lbl_sub.text = texto
	_lbl_sub.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(duracion)
	t.tween_property(_lbl_sub, "modulate:a", 0.0, 0.3)


## a_negro = true oscurece la pantalla, false la aclara
func fundido(a_negro: bool, duracion := 0.5) -> void:
	_negro.modulate.a = 0.0 if a_negro else 1.0
	create_tween().tween_property(_negro, "modulate:a", 1.0 if a_negro else 0.0, duracion)


func mostrar_fin(titulo: String, subtitulo: String, puntos: int,
		ayuda := "ENTER O TOCAR PARA SEGUIR") -> void:
	_fin = ColorRect.new()
	(_fin as ColorRect).color = Color(0.05, 0.02, 0.05, 0.75)
	_fin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fin.modulate.a = 0.0
	add_child(_fin)
	var t1 := _label(titulo, 16, Vector2(0, 26), C_DORADO, Vector2(240, 18), HORIZONTAL_ALIGNMENT_CENTER)
	var t2 := _label(subtitulo, 8, Vector2(12, 52), C_TEXTO, Vector2(216, 20), HORIZONTAL_ALIGNMENT_CENTER)
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var t3 := _label("PUNTOS  %06d" % puntos, 8, Vector2(0, 80), C_DORADO, Vector2(240, 10), HORIZONTAL_ALIGNMENT_CENTER)
	var t4 := _label(ayuda, 8, Vector2(0, 108), C_TEXTO, Vector2(240, 10), HORIZONTAL_ALIGNMENT_CENTER)
	for l in [t1, t2, t3, t4]:
		remove_child(l)
		_fin.add_child(l)
	create_tween().tween_property(_fin, "modulate:a", 1.0, 0.5)


# ---------- Dibujo ----------

func _dibujar() -> void:
	for p in _paneles:
		_dibujar_panel(p)
	# Barra del jefe: arriba al centro (1 jugador) o abajo al centro (2 jugadores)
	if _jefe_vida >= 0.0:
		var r := Rect2(60, 124, 120, 4) if _dos else Rect2(88, 13, 92, 4)
		_barra(r, _jefe_vida / _jefe_max, _jefe_lenta / _jefe_max, false)


func _dibujar_panel(p: Dictionary) -> void:
	var x: float = p["x"]
	var vida: float = p["vida"]
	var vmax: float = p["max"]
	_lienzo.draw_rect(Rect2(x, 1, 80, 33), Color(0, 0, 0, 0.35))
	_barra(Rect2(x + 3, 13, 74, 4), vida / vmax, p["lenta"] / vmax, vida > 0.0 and vida < vmax * 0.25)

	# Barra de RABIA (se llena con vino)
	_lienzo.draw_texture_rect_region(TEX_ITEMS, Rect2(x, 18, 16, 16), ICONO_VINO)
	var r := Rect2(x + 17, 30, 60, 2)
	_lienzo.draw_rect(r.grow(1), C_BORDE)
	_lienzo.draw_rect(r, C_FONDO)
	var rabia: float = p["rabia"]
	var activa: bool = p["activa"]
	var llena := rabia >= 100.0 and not activa
	var parpadeo := (Time.get_ticks_msec() / 120) % 2 == 0
	var color := C_RABIA
	if llena or activa:
		color = C_RABIA_LUZ if parpadeo else C_RABIA_LLENA
	_lienzo.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(rabia / 100.0, 0, 1), r.size.y)), color)
	var texto := "RABIA"
	if vida <= 0.0:
		texto = "CAYO"
	elif activa:
		texto = "¡RABIA!"
	elif llena:
		# en 2 jugadores no entra la tecla en el panel
		texto = "¡LISTA!" if (_dos or DisplayServer.is_touchscreen_available()) \
			else "¡LISTA! [%s]" % Entradas.tecla_rabia(p["numero"])
	var pos_texto := Vector2(x + 17, 27)
	_lienzo.draw_string_outline(Fuente.fuente(), pos_texto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, C_BORDE)
	_lienzo.draw_string(Fuente.fuente(), pos_texto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		C_RABIA_LUZ if (llena or activa) else C_TEXTO)


func _barra(r: Rect2, valor: float, valor_lento: float, parpadea: bool) -> void:
	_lienzo.draw_rect(r.grow(1), C_BORDE)
	_lienzo.draw_rect(r, C_FONDO)
	_lienzo.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(valor_lento, 0, 1), r.size.y)), C_DANIO)
	var lleno := Rect2(r.position, Vector2(r.size.x * clampf(valor, 0, 1), r.size.y))
	var color := C_VIDA
	if parpadea and (Time.get_ticks_msec() / 200) % 2 == 0:
		color = C_VIDA_LUZ
	_lienzo.draw_rect(lleno, color)
	_lienzo.draw_rect(Rect2(lleno.position, Vector2(lleno.size.x, 1)), C_VIDA_LUZ)


func _label(texto: String, tamanio: int, pos: Vector2, color: Color,
		tam := Vector2.ZERO, alineacion := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = texto
	l.label_settings = Fuente.ajustes(tamanio, color)
	l.position = pos
	if tam != Vector2.ZERO:
		l.size = tam
	l.horizontal_alignment = alineacion
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
