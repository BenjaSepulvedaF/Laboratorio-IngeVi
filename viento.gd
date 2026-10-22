extends Area3D

# Zona de viento: mientras el jugador está dentro, lanza ráfagas periódicas.
@export var direccion := Vector3(1, 0, 0)
@export var aceleracion := 10.0
@export var duracion_rafaga := 0.5
@export var intervalo := 2.2

var jugador = null
var tiempo := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		jugador = body
		tiempo = randf_range(0.5, intervalo)


func _on_body_exited(body: Node3D) -> void:
	if body == jugador:
		jugador = null


func _physics_process(delta: float) -> void:
	if jugador == null:
		return
	tiempo -= delta
	if tiempo <= 0.0:
		tiempo = intervalo
		jugador.aplicar_viento(direccion.normalized() * aceleracion, duracion_rafaga)
