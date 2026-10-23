extends Area3D

# Puerta que lleva a otro nivel. Al entrar marca el inicio directo, para que el nivel
# empiece sin mostrar de nuevo el menú de inicio.
@export var escena := "res://mundo.tscn"
@export var marca_inicio := true
@export var texto := "Puerta"

const AUTO_INICIO := &"volcan_inicio_directo"

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
	get_tree().change_scene_to_file.call_deferred(escena)
