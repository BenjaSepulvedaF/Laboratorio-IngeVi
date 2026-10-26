extends Area3D

# Zona de viento: mientras el jugador está dentro, lanza ráfagas periódicas.
@export var direccion := Vector3(1, 0, 0)
@export var aceleracion := 10.0
@export var duracion_rafaga := 0.5
@export var intervalo := 2.2

var jugador = null
var tiempo := 0.0
var particulas: GPUParticles3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_crear_particulas()


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
		if jugador.aplicar_viento(direccion.normalized() * aceleracion, duracion_rafaga):
			_mostrar_rafaga()


# Líneas semitransparentes que recorren la zona en la dirección del viento.
func _crear_particulas() -> void:
	var forma: BoxShape3D = $CollisionShape3D.shape

	var proceso := ParticleProcessMaterial.new()
	proceso.direction = direccion.normalized()
	proceso.spread = 8.0
	proceso.initial_velocity_min = 6.0
	proceso.initial_velocity_max = 9.0
	proceso.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proceso.emission_box_extents = forma.size * 0.5
	proceso.particle_flag_align_y = true

	var linea := BoxMesh.new()
	linea.size = Vector3(0.03, 0.8, 0.03)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.9, 0.95, 1, 0.45)
	linea.material = material

	particulas = GPUParticles3D.new()
	particulas.amount = 60
	particulas.lifetime = 0.8
	particulas.emitting = false
	particulas.process_material = proceso
	particulas.draw_pass_1 = linea
	add_child(particulas)


func _mostrar_rafaga() -> void:
	particulas.restart()
	particulas.emitting = true
	get_tree().create_timer(duracion_rafaga).timeout.connect(func(): particulas.emitting = false)
