extends Area3D

# Puerta que lleva a otro nivel. Al entrar marca el inicio directo, para que el nivel
# empiece sin mostrar de nuevo el menú de inicio.
@export var escena := "res://niveles/mundo/mundo.tscn"
@export var marca_inicio := true
@export var texto := "Puerta"

const AUTO_INICIO := &"volcan_inicio_directo"
# Cambiar de escena destruye al jugador; esta marca lleva el orbe al nivel siguiente.
const ORBE_LLEVADO := &"volcan_orbe_llevado"
const SONIDO_PORTAL = preload("res://assets/audio/portal.wav")
# portal.wav dura ~6 s; se desvanece antes para no tapar el inicio del otro nivel.
const DURACION_SONIDO := 2.5

var activa := true


func _ready() -> void:
	$Etiqueta.text = texto
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not activa or not body.is_in_group("jugador"):
		return
	activa = false
	if marca_inicio:
		get_tree().set_meta(AUTO_INICIO, true)
	get_tree().set_meta(ORBE_LLEVADO, body.objeto_llevado != "")
	# Suelto: el cambio de escena destruye la puerta y cortaría el sonido.
	SonidoSuelto.reproducir(get_tree(), SONIDO_PORTAL, -3.0, DURACION_SONIDO)
	get_tree().change_scene_to_file.call_deferred(escena)
