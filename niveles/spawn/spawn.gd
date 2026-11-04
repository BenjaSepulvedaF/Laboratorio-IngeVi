extends Node3D

# Punto de inicio del juego. Desde aquí se entra a los niveles a través de las puertas.
const ORBE_LLEVADO := &"volcan_orbe_llevado"


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Si se llegó por una puerta cargando el orbe, el jugador lo sigue llevando.
	if get_tree().get_meta(ORBE_LLEVADO, false):
		$Jugador.equipar_orbe(true)
