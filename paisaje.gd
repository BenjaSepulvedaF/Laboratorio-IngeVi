@tool
extends Node3D

# Geometría decorativa determinista, visible también dentro del editor.
# No tiene colisiones: únicamente los apoyos del circuito son transitables.
func _ready() -> void:
	var anterior := get_node_or_null("Geometria")
	if anterior:
		anterior.free()
	var geometria := Node3D.new()
	geometria.name = "Geometria"
	add_child(geometria)
	var rng := RandomNumberGenerator.new()
	rng.seed = 22062026
	var roca := StandardMaterial3D.new()
	roca.vertex_color_use_as_albedo = true
	roca.roughness = 1.0
	# El volcán es un cono truncado irregular con cráter, no una montaña sólida.
	_relieve(geometria, Vector3(0, -4, -127), 36.0, 32.0, 6.0, roca, rng)
	var fuego := StandardMaterial3D.new()
	fuego.albedo_color = Color(0.9, 0.16, 0.015)
	fuego.emission_enabled = true
	fuego.emission = Color(1, 0.16, 0.01)
	fuego.emission_energy_multiplier = 3.0
	var crater := CylinderMesh.new()
	crater.top_radius = 5.7
	crater.bottom_radius = 5.7
	crater.height = 0.25
	crater.radial_segments = 20
	_malla(geometria, crater, fuego, Vector3(0, 27.2, -127))
	for i in range(14):
		var lado := -1.0 if i % 2 == 0 else 1.0
		var posicion := Vector3(lado * rng.randf_range(28, 55), -5, 10 - i * 9)
		_relieve(geometria, posicion, rng.randf_range(14, 23), rng.randf_range(12, 24), rng.randf_range(1, 4), roca, rng)
	var basalto := StandardMaterial3D.new()
	basalto.albedo_color = Color(0.16, 0.15, 0.18)
	basalto.roughness = 0.95
	for i in range(65):
		var columna := CylinderMesh.new()
		columna.radial_segments = 6
		columna.top_radius = rng.randf_range(0.4, 1.3)
		columna.bottom_radius = columna.top_radius * 1.25
		columna.height = rng.randf_range(3, 10)
		var lado := -1.0 if i % 2 == 0 else 1.0
		_malla(geometria, columna, basalto, Vector3(lado * rng.randf_range(13, 27), columna.height * 0.3 - 1, rng.randf_range(-100, 8)))
	if not Engine.is_editor_hint():
		_particulas(geometria, false)
		_particulas(geometria, true)


func _relieve(padre: Node3D, posicion: Vector3, radio: float, altura: float, boca: float, material: Material, rng: RandomNumberGenerator) -> void:
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base: Array[Vector3] = []
	var medio: Array[Vector3] = []
	var cima: Array[Vector3] = []
	for i in range(19):
		var angulo := i % 18 * TAU / 18.0
		var radial := Vector3(cos(angulo), 0, sin(angulo))
		base.append(radial * radio * rng.randf_range(0.9, 1.1))
		medio.append(radial * radio * 0.55 + Vector3.UP * altura * rng.randf_range(0.36, 0.5))
		cima.append(radial * boca + Vector3.UP * altura)
	base[18] = base[0]
	medio[18] = medio[0]
	cima[18] = cima[0]
	for i in range(18):
		var color := Color(0.25, 0.22, 0.24) * rng.randf_range(0.65, 1.3)
		_triangulo(superficie, base[i], medio[i], base[i + 1], color)
		_triangulo(superficie, base[i + 1], medio[i], medio[i + 1], color * 0.9)
		_triangulo(superficie, medio[i], cima[i], medio[i + 1], color * 0.8)
		_triangulo(superficie, medio[i + 1], cima[i], cima[i + 1], color * 0.85)
	_malla(padre, superficie.commit(), material, posicion)


func _triangulo(superficie: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for vertice in [a, b, c]:
		superficie.set_normal(normal)
		superficie.set_color(color)
		superficie.add_vertex(vertice)


func _malla(padre: Node3D, mesh: Mesh, material: Material, posicion: Vector3) -> void:
	var instancia := MeshInstance3D.new()
	instancia.mesh = mesh
	instancia.material_override = material
	instancia.position = posicion
	padre.add_child(instancia)


func _particulas(padre: Node3D, ceniza: bool) -> void:
	var particulas := GPUParticles3D.new()
	particulas.name = "Ceniza" if ceniza else "Ascuas"
	particulas.amount = 100 if ceniza else 70
	particulas.lifetime = 9.0
	particulas.preprocess = 3.0
	particulas.position = Vector3(0, 7 if ceniza else 1, -44)
	particulas.visibility_aabb = AABB(Vector3(-25, -15, -65), Vector3(50, 45, 130))
	var proceso := ParticleProcessMaterial.new()
	proceso.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proceso.emission_box_extents = Vector3(18, 5 if ceniza else 0.5, 50)
	proceso.direction = Vector3(0.3, -1 if ceniza else 1, 0.1)
	proceso.spread = 25
	proceso.initial_velocity_min = 0.3
	proceso.initial_velocity_max = 1.2
	proceso.gravity = Vector3(0.03, -0.04 if ceniza else 0.05, 0)
	particulas.process_material = proceso
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.45, 0.4, 0.4) if ceniza else Color(1, 0.45, 0.08)
	material.emission_enabled = not ceniza
	material.emission = Color(1, 0.2, 0.01)
	material.emission_energy_multiplier = 2.0
	var esfera := SphereMesh.new()
	esfera.radius = 0.025
	esfera.height = 0.05
	esfera.radial_segments = 4
	esfera.rings = 2
	esfera.material = material
	particulas.draw_pass_1 = esfera
	padre.add_child(particulas)
