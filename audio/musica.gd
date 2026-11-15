extends Node

# Música de fondo (autoload "Musica"). Al ser autoload no se destruye al cambiar de
# escena: sigue sonando sin cortarse al cruzar los portales.
#
# musica_loop.mp3 termina con un fundido de ~4.5 s y empieza con ~0.3 s de silencio,
# así que repetirla tal cual dejaría un hueco. En su lugar se alternan dos
# reproductores: cuando uno llega al fundido final, el otro empieza desde el principio
# y se mezclan (crossfade).
const MUSICA = preload("res://assets/audio/musica_loop.mp3")
const VOLUMEN := -18.0
const INICIO := 0.28 # salta el silencio inicial
const ANTES_DEL_FINAL := 5.0 # segundos antes del final en que empieza el cruce
const CRUCE := 3.0
const BAJADA_EN_PAUSA := -8.0 # en los menús la música baja para no molestar

var reproductores: Array[AudioStreamPlayer] = []
var actual := 0
var cruzando := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var reproductor := AudioStreamPlayer.new()
		reproductor.stream = MUSICA
		reproductor.bus = &"Musica"
		reproductor.volume_db = VOLUMEN
		add_child(reproductor)
		reproductores.append(reproductor)
	reproductores[actual].play(INICIO)


func _process(delta: float) -> void:
	var sonando := reproductores[actual]
	if not cruzando and sonando.get_playback_position() >= MUSICA.get_length() - ANTES_DEL_FINAL:
		_cruzar()
	# Baja suavemente en pausa y vuelve al reanudar.
	var bus := AudioServer.get_bus_index(&"Musica")
	var objetivo := BAJADA_EN_PAUSA if get_tree().paused else 0.0
	AudioServer.set_bus_volume_db(bus, move_toward(AudioServer.get_bus_volume_db(bus), objetivo, 20.0 * delta))


func _cruzar() -> void:
	cruzando = true
	var saliente := reproductores[actual]
	actual = 1 - actual
	var entrante := reproductores[actual]
	entrante.volume_db = -40.0
	entrante.play(INICIO)
	var tween := create_tween().set_parallel()
	tween.tween_property(entrante, "volume_db", VOLUMEN, CRUCE)
	tween.tween_property(saliente, "volume_db", -40.0, CRUCE + 1.0)
	tween.chain().tween_callback(func():
		saliente.stop()
		saliente.volume_db = VOLUMEN
		cruzando = false)
