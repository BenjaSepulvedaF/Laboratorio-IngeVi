class_name SonidoSuelto
extends RefCounted

# Reproduce un sonido colgado de la raíz del árbol, fuera de la escena actual.
# Cambiar o recargar la escena (portales, Reintentar) destruye todos sus nodos y
# cortaría el sonido en seco; colgado de la raíz sobrevive y se borra solo al terminar.
#
# duracion_max > 0 desvanece el sonido para que dure como máximo esos segundos
# (útil para sonidos largos con mucha cola).

const DESVANECIDO := 0.6


static func reproducir(arbol: SceneTree, sonido: AudioStream, volumen_db := -3.0, duracion_max := 0.0) -> void:
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = sonido
	reproductor.volume_db = volumen_db
	reproductor.bus = &"SFX"
	# Debe sonar aunque el juego esté en pausa (por ejemplo, un clic en el menú de pausa).
	reproductor.process_mode = Node.PROCESS_MODE_ALWAYS
	arbol.root.add_child(reproductor)
	reproductor.play()
	reproductor.finished.connect(reproductor.queue_free)
	if duracion_max > 0.0:
		var tween := reproductor.create_tween()
		tween.tween_interval(maxf(duracion_max - DESVANECIDO, 0.0))
		tween.tween_property(reproductor, "volume_db", -40.0, DESVANECIDO)
		tween.tween_callback(reproductor.queue_free)
