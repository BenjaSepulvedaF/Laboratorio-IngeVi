extends Node3D

@export var flotar := true
var tiempo := 0.0
var intensidad := 0.0
var tween_pulso: Tween
@onready var visual: Node3D = $Visual


func _process(delta: float) -> void:
	tiempo += delta
	visual.position.y = sin(tiempo * 2.2) * 0.055 if flotar else 0.0
	visual.scale = Vector3.ONE * (1.0 + sin(tiempo * 3.0) * 0.035 + intensidad * 0.35)
	$Visual/Anillo.rotation.y += delta * 0.8
	$Visual/Anillo2.rotation.z -= delta * 0.6
	$Luz.light_energy = 0.65 + sin(tiempo * 3.0) * 0.12 + intensidad * 2.0


func destellar() -> void:
	if tween_pulso:
		tween_pulso.kill()
	intensidad = 1.0
	tween_pulso = create_tween()
	tween_pulso.tween_property(self, "intensidad", 0.0, 0.65)
