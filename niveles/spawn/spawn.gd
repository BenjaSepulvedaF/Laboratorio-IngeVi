extends Node3D

# Punto de inicio del juego. Desde aquí se entra a los niveles a través de las puertas.
const ORBE_LLEVADO := &"volcan_orbe_llevado"

@onready var jugador = $Jugador
@onready var interfaz = $Interfaz


func _ready() -> void:
	# El vestíbulo no tiene menú de inicio ni derrota: solo pausa.
	interfaz.cerrar_menu()
	interfaz.mostrar_objetivo("vestibulo")
	interfaz.pausa_solicitada.connect(_alternar_pausa)
	interfaz.jugar_solicitado.connect(_reanudar)
	jugador.agarre_cambiado.connect(interfaz.mostrar_agarre)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Si se llegó por una puerta cargando el orbe, el jugador lo sigue llevando.
	if get_tree().get_meta(ORBE_LLEVADO, false):
		jugador.equipar_orbe(true)
		interfaz.mostrar_objetivo("espalda")


func _alternar_pausa() -> void:
	interfaz.reproducir_pausa()
	if get_tree().paused:
		_reanudar()
	else:
		interfaz.mostrar_menu("PAUSA")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true


func _reanudar() -> void:
	get_tree().paused = false
	interfaz.cerrar_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
