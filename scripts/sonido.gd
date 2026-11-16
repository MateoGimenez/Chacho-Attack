extends Node
## Autoload "Sonido": efectos de sonido de todo el juego.
##   Sonido.tocar("golpe")              → suena con ±7% de variación de tono
##   Sonido.tocar("disparo", -4.0)      → 4 dB más bajo
##   Sonido.tocar("menu_mover", 0, 0)   → sin variación de tono
## Los archivos están en res://audio/sfx/ (se regeneran con fuentes/gen_sfx.py).
## Van por el bus "SFX" (volumen general en default_bus_layout.tres).

const CARPETA := "res://audio/sfx/%s.wav"

## Todos los sonidos del juego (la lista va escrita a mano porque en la versión web
## no se puede listar la carpeta).
const NOMBRES := [
	"lanza_1", "lanza_2", "lanza_3", "sable_1", "sable_2", "sable_3", "tigre", "golpe", "golpe_fuerte", "bloqueo",
	"chacho_dolor", "chacho_muere", "rabia_lista", "rabia",
	"espadazo", "culatazo", "disparo", "aviso_enemigo", "enemigo_cae",
	"comer", "vino", "harina", "barril_golpe", "barril_rompe",
	"menu_mover", "menu_aceptar", "menu_volver", "logo",
	"adelante", "jefe", "nivel_completo", "victoria", "game_over", "trueno", "piedra",
	# jefes (v7, fuentes/gen_sfx_jefes.py)
	"silbido", "esquiva", "galope", "tintero", "libro", "megafono", "aturdido", "lanzar",
	"billetes", "escudo", "motor", "pala", "clank", "explosion",
]

## Ajuste de volumen por sonido (dB). Los tonos "cuadrados" suenan más fuerte que los golpes.
const VOLUMEN := {
	"rabia_lista": -7.0, "comer": -6.0, "menu_aceptar": -6.0, "menu_volver": -5.0,
	"menu_mover": -4.0, "adelante": -5.0, "harina": -5.0, "jefe": -6.0, "chacho_dolor": -4.0,
	"nivel_completo": -4.0, "victoria": -4.0, "game_over": -4.0, "vino": -3.0,
	"silbido": -3.0, "aturdido": -6.0, "escudo": -5.0, "billetes": -3.0, "megafono": -2.0,
}

const CANALES := 14              # cuántos sonidos pueden sonar a la vez
const MISMO_SONIDO_MS := 35      # si el mismo sonido se pide 2 veces en este tiempo, suena 1 sola vez

var _streams := {}
var _canales: Array[AudioStreamPlayer] = []
var _siguiente := 0
var _ultima_vez := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # que suene aunque el juego esté congelado (hit-stop)
	for nombre: String in NOMBRES:
		var ruta := CARPETA % nombre
		if ResourceLoader.exists(ruta):
			_streams[nombre] = load(ruta)
		else:
			push_warning("Falta el sonido " + ruta)
	for i in CANALES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_canales.append(p)


func tocar(nombre: String, volumen_db := 0.0, variacion := 0.07) -> void:
	if not _streams.has(nombre):
		return
	var ahora := Time.get_ticks_msec()
	if ahora - int(_ultima_vez.get(nombre, -1000)) < MISMO_SONIDO_MS:
		return
	_ultima_vez[nombre] = ahora
	var p := _canal_libre()
	p.stream = _streams[nombre]
	p.volume_db = volumen_db + float(VOLUMEN.get(nombre, 0.0))
	p.pitch_scale = randf_range(1.0 - variacion, 1.0 + variacion)
	p.play()


func _canal_libre() -> AudioStreamPlayer:
	for i in CANALES:
		var p := _canales[(_siguiente + i) % CANALES]
		if not p.playing:
			_siguiente = (_siguiente + i + 1) % CANALES
			return p
	# todos ocupados: se pisa el más viejo
	var p := _canales[_siguiente]
	_siguiente = (_siguiente + 1) % CANALES
	return p
