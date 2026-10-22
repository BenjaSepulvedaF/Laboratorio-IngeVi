extends Node3D

# RECOGER: altar del que se toma el objeto (empieza lleno).
# COLOCAR: altar donde se deja el objeto (empieza vacío).
enum Modo { RECOGER, COLOCAR }

@export var modo: Modo = Modo.RECOGER
@export var nombre_objeto := "Orbe Sagrado"

var jugador_cerca = null
var tiene_objeto := false
var completado := false

@onready var orbe: Node3D = $Orbe
@onready var area: Area3D = $Area3D
@onready var etiqueta: Label3D = $Etiqueta

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	tiene_objeto = modo == Modo.RECOGER
	orbe.visible = tiene_objeto
	_actualizar_etiqueta()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		jugador_cerca = body
		_actualizar_etiqueta()

func _on_body_exited(body: Node3D) -> void:
	if body == jugador_cerca:
		jugador_cerca = null
		_actualizar_etiqueta()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		return
	if jugador_cerca == null:
		return
	if modo == Modo.RECOGER:
		_recoger()
	else:
		_colocar()

func _recoger() -> void:
	if not tiene_objeto or jugador_cerca.objeto_llevado != "":
		return
	jugador_cerca.objeto_llevado = nombre_objeto
	jugador_cerca.play_grab()
	tiene_objeto = false
	orbe.visible = false
	_actualizar_etiqueta()

func _colocar() -> void:
	if completado or jugador_cerca.objeto_llevado != nombre_objeto:
		return
	jugador_cerca.objeto_llevado = ""
	jugador_cerca.play_grab()
	tiene_objeto = true
	completado = true
	orbe.visible = true
	_actualizar_etiqueta()

func _actualizar_etiqueta() -> void:
	if modo == Modo.RECOGER:
		if not tiene_objeto:
			etiqueta.text = "Altar vacio"
		elif jugador_cerca != null:
			etiqueta.text = "[E] Recoger " + nombre_objeto
		else:
			etiqueta.text = nombre_objeto
	else:
		if completado:
			etiqueta.text = "¡" + nombre_objeto + " colocado!"
		elif jugador_cerca != null and jugador_cerca.objeto_llevado == nombre_objeto:
			etiqueta.text = "[E] Colocar " + nombre_objeto
		elif jugador_cerca != null:
			etiqueta.text = "Necesitas: " + nombre_objeto
		else:
			etiqueta.text = "Altar vacio"
