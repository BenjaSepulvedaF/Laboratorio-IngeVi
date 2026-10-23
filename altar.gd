extends Node3D

signal interaccion_solicitada(altar: Node3D, jugador: CharacterBody3D)

enum Modo { RECOGER, COLOCAR }
@export var modo: Modo = Modo.RECOGER
@export var nombre_objeto := "Orbe Sagrado"

var jugador_cerca = null
var tiene_objeto := false
var completado := false
var habilitado := true
@onready var orbe: Node3D = $Orbe
@onready var etiqueta: Label3D = $Etiqueta


func _ready() -> void:
	$Area3D.body_entered.connect(_on_body_entered)
	$Area3D.body_exited.connect(_on_body_exited)
	establecer_objeto(modo == Modo.RECOGER)


func establecer_objeto(presente: bool, terminado: bool = false) -> void:
	tiene_objeto = presente
	completado = terminado
	orbe.visible = presente
	actualizar_etiqueta()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		jugador_cerca = body
		actualizar_etiqueta()


func _on_body_exited(body: Node3D) -> void:
	if body == jugador_cerca:
		jugador_cerca = null
		actualizar_etiqueta()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		return
	if not habilitado or jugador_cerca == null or not jugador_cerca.puede_interactuar():
		return
	interaccion_solicitada.emit(self, jugador_cerca)
	get_viewport().set_input_as_handled()


func actualizar_etiqueta() -> void:
	if not is_node_ready():
		return
	if modo == Modo.RECOGER:
		etiqueta.text = "Orbe recuperado" if not tiene_objeto else nombre_objeto
		if tiene_objeto and jugador_cerca != null and habilitado:
			etiqueta.text = "[E] Recoger " + nombre_objeto
	elif completado:
		etiqueta.text = "Orbe colocado"
	elif jugador_cerca != null and habilitado:
		etiqueta.text = "[E] Colocar el orbe" if jugador_cerca.objeto_llevado != "" else "Recupera el orbe"
	else:
		etiqueta.text = "Altar de origen"
