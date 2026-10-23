extends Node3D

# Punto de inicio del juego. Desde aquí se entra a los niveles a través de las puertas.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
