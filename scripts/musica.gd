extends Node
## Autoload "Musica": una canción por pantalla, en loop, con fundido entre canciones.
##   Musica.tocar("catedral")   → si ya está sonando esa, no hace nada
##   Musica.parar(1.0)          → se apaga en 1 segundo
## Las canciones están en res://audio/musica/ (OGG). Van por el bus "Musica".
##
##   menu      → Carnaval de La Rioja (8 bit)
##   catedral  → Chayita del Vidalero (8 bit)
##   superdomo → Cuando era Chango (8 bit)
##   chaya     → El Camión de Germán (8 bit)

const CARPETA := "res://audio/musica/%s.ogg"
const VOLUMEN_DB := 0.0
const SILENCIO_DB := -40.0

var actual := ""
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _crear_reproductor()
	_b = _crear_reproductor()


func _crear_reproductor() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Musica"
	p.volume_db = SILENCIO_DB
	add_child(p)
	return p


func tocar(nombre: String, fundido := 0.8) -> void:
	if nombre == actual and _a.playing:
		return
	var ruta := CARPETA % nombre
	if not ResourceLoader.exists(ruta):
		push_warning("Falta la canción " + ruta)
		return
	actual = nombre
	var stream: AudioStream = load(ruta)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	# la que sonaba pasa a _b y se apaga; la nueva entra en _a
	var viejo := _a
	_a = _b
	_b = viejo
	_a.stream = stream
	_a.volume_db = SILENCIO_DB
	_a.play()
	_fundir(fundido)


func parar(fundido := 0.6) -> void:
	actual = ""
	var viejo := _a
	_a = _b
	_b = viejo
	_a.stop()
	_fundir(fundido)


func _fundir(duracion: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	if _a.playing:
		_tween.tween_property(_a, "volume_db", VOLUMEN_DB, duracion).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_b, "volume_db", SILENCIO_DB, duracion).set_trans(Tween.TRANS_SINE)
	_tween.chain().tween_callback(_b.stop)
