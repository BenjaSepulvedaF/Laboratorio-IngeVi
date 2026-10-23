extends Node3D

enum Estado { INICIO, JUGANDO, PAUSA, DERROTA, ENTREGA, VICTORIA }
const ORBE = preload("res://orbe.tscn")
const AUTO_INICIO := &"volcan_inicio_directo"

var estado: Estado = Estado.INICIO
var estado_antes_pausa: Estado = Estado.JUGANDO
var tween_entrega: Tween
var orbe_transito: Node3D
var entrega_desde := Vector3.ZERO
var entrega_hasta := Vector3.ZERO
@onready var jugador = $Jugador
@onready var origen = $AltarRecoger
@onready var destino = $AltarColocar
@onready var interfaz = $Interfaz


func _ready() -> void:
	orbe_transito = ORBE.instantiate()
	orbe_transito.name = "OrbeEnTransito"
	orbe_transito.flotar = false
	orbe_transito.visible = false
	add_child(orbe_transito)
	origen.interaccion_solicitada.connect(_interactuar)
	destino.interaccion_solicitada.connect(_interactuar)
	jugador.caida.connect(_morir)
	jugador.agarre_cambiado.connect(interfaz.mostrar_agarre)
	$Lava/ZonaLetal.body_entered.connect(_tocar_lava)
	interfaz.jugar_solicitado.connect(_jugar)
	interfaz.reinicio_solicitado.connect(reiniciar)
	interfaz.pausa_solicitada.connect(_alternar_pausa)
	_establecer_orbe("origen")
	if get_tree().has_meta(AUTO_INICIO):
		get_tree().remove_meta(AUTO_INICIO)
		_jugar()
	else:
		jugador.bloquear()
		_menu(Estado.INICIO)


func _jugar() -> void:
	if estado == Estado.PAUSA:
		estado = estado_antes_pausa
	else:
		estado = Estado.JUGANDO
		jugador.desbloquear()
	get_tree().paused = false
	interfaz.cerrar_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _menu(nuevo: Estado) -> void:
	estado = nuevo
	interfaz.mostrar_menu(Estado.keys()[nuevo])
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true


func _alternar_pausa() -> void:
	if estado == Estado.PAUSA:
		_jugar()
	elif estado == Estado.JUGANDO or estado == Estado.ENTREGA:
		estado_antes_pausa = estado
		_menu(Estado.PAUSA)


func _tocar_lava(body: Node3D) -> void:
	if body == jugador:
		_morir()


func _morir() -> void:
	if estado != Estado.JUGANDO and estado != Estado.ENTREGA:
		return
	if tween_entrega:
		tween_entrega.kill()
	jugador.bloquear()
	_establecer_orbe("origen")
	_menu(Estado.DERROTA)


# Este es el único punto que decide dónde existe el orbe.
func _establecer_orbe(lugar: String) -> void:
	origen.establecer_objeto(lugar == "origen")
	destino.establecer_objeto(lugar == "destino", lugar == "destino")
	jugador.equipar_orbe(lugar == "espalda")
	orbe_transito.visible = lugar == "transito"
	origen.habilitado = lugar == "origen"
	destino.habilitado = lugar == "espalda"
	origen.actualizar_etiqueta()
	destino.actualizar_etiqueta()
	interfaz.mostrar_objetivo(lugar)
	if lugar == "transito":
		destino.etiqueta.text = "Colocando el orbe…"


func _interactuar(altar: Node3D, actor: CharacterBody3D) -> void:
	if estado != Estado.JUGANDO or actor != jugador or not jugador.puede_interactuar():
		return
	if altar == origen and origen.tiene_objeto and jugador.objeto_llevado == "":
		_establecer_orbe("espalda")
		jugador.play_grab()
	elif altar == destino and jugador.objeto_llevado != "" and not destino.completado:
		_entregar()


func _entregar() -> void:
	estado = Estado.ENTREGA
	entrega_desde = jugador.posicion_orbe()
	entrega_hasta = destino.orbe.global_position
	jugador.bloquear()
	jugador.play_grab()
	_establecer_orbe("transito")
	_animar_entrega(0.0)
	tween_entrega = create_tween()
	tween_entrega.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween_entrega.tween_method(_animar_entrega, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_entrega.tween_callback(_terminar_entrega)


func _animar_entrega(progreso: float) -> void:
	orbe_transito.global_position = entrega_desde.lerp(entrega_hasta, progreso) + Vector3.UP * sin(progreso * PI) * 1.1


func _terminar_entrega() -> void:
	if estado != Estado.ENTREGA:
		return
	_establecer_orbe("destino")
	destino.orbe.destellar()
	tween_entrega = create_tween()
	tween_entrega.tween_interval(0.4)
	tween_entrega.tween_callback(func(): _menu(Estado.VICTORIA))


func reiniciar() -> void:
	get_tree().set_meta(AUTO_INICIO, true)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var error := get_tree().reload_current_scene()
	if error != OK:
		get_tree().remove_meta(AUTO_INICIO)
		push_error("No se pudo reiniciar el escenario: " + error_string(error))
		_menu(Estado.DERROTA)
