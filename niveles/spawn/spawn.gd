extends Node3D

# Vestíbulo: punto de inicio del juego. Desde aquí se entra a los niveles por las
# puertas, y aquí se colocan los orbes en el monumento. Colocar el orbe del último
# nivel (Progreso.NIVELES) es la victoria.
const ORBE_LLEVADO := &"volcan_orbe_llevado"

@onready var jugador = $Jugador
@onready var interfaz = $Interfaz
@onready var monumento = $MonumentoOrbes


func _ready() -> void:
	# El vestíbulo no tiene menú de inicio ni derrota: solo pausa y victoria.
	interfaz.cerrar_menu()
	interfaz.pausa_solicitada.connect(_alternar_pausa)
	interfaz.jugar_solicitado.connect(_reanudar)
	interfaz.reinicio_solicitado.connect(_jugar_de_nuevo)
	jugador.agarre_cambiado.connect(interfaz.mostrar_agarre)
	monumento.entrega_terminada.connect(_on_entrega_terminada)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Si se llegó por una puerta cargando un orbe, el jugador lo sigue llevando.
	# La marca se consume aquí para que no reaparezca al recargar el vestíbulo.
	var orbe: String = get_tree().get_meta(ORBE_LLEVADO, "")
	if get_tree().has_meta(ORBE_LLEVADO):
		get_tree().remove_meta(ORBE_LLEVADO)
	if orbe != "":
		jugador.equipar_orbe(true, orbe)
		interfaz.mostrar_objetivo("monumento")
	else:
		interfaz.mostrar_objetivo("vestibulo")


func _on_entrega_terminada(id: String) -> void:
	if Progreso.completo():
		jugador.atenuar_entrega()
		interfaz.mostrar_menu("VICTORIA")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true
	else:
		# Aún quedan niveles: el portal del siguiente ya se abrió (puerta.gd).
		jugador.desbloquear()
		interfaz.mostrar_objetivo("portal_abierto")


func _alternar_pausa() -> void:
	if interfaz.menu_actual == "VICTORIA" and get_tree().paused:
		return # la victoria solo se cierra con sus botones
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


# Desde la victoria: se borra el progreso y se empieza otra vez desde el vestíbulo.
func _jugar_de_nuevo() -> void:
	Progreso.reiniciar()
	get_tree().paused = false
	get_tree().reload_current_scene()
