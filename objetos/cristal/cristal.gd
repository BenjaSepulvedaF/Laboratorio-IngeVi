class_name Cristal
extends Area3D

# Cristal de agua: recupera parte de la resistencia al calor. Está al final de
# los desvíos del parkour (callejones sin salida más difíciles que el camino
# principal). Es de un solo uso: si se gastan todos a la ida, a la vuelta ya no
# quedan. Se construye por código para que el generador pueda crearlo donde
# termine cada desvío.

signal recogido(cristal: Cristal)

const COLOR_AGUA := Color(0.35, 0.85, 1.0)
# Fracción de la barra que recupera. Un desvío cuesta unos 10-15 s de calor, así
# que debe devolver bastante más para que valga la pena arriesgarse.
@export var recuperacion := 0.4

var tomado := false
var gema: MeshInstance3D
var luz: OmniLight3D
var sonido: AudioStreamPlayer3D
var tiempo := randf() * TAU


func _ready() -> void:
	add_to_group("cristales")
	collision_layer = 0
	collision_mask = 4 # capa del jugador
	monitorable = false
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.8
	forma.shape = esfera
	add_child(forma)
	# Gema: un prisma de 6 caras estirado, que brilla y se ve desde lejos.
	gema = MeshInstance3D.new()
	var malla := CylinderMesh.new()
	malla.top_radius = 0.0
	malla.bottom_radius = 0.28
	malla.height = 0.5
	malla.radial_segments = 6
	malla.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_AGUA
	material.emission_enabled = true
	material.emission = COLOR_AGUA
	material.emission_energy_multiplier = 2.2
	material.metallic = 0.3
	material.roughness = 0.15
	malla.material = material
	var punta_inferior := MeshInstance3D.new()
	punta_inferior.mesh = malla
	punta_inferior.rotation.x = PI
	punta_inferior.position.y = -0.5
	gema.mesh = malla
	gema.add_child(punta_inferior)
	gema.position.y = 0.25
	add_child(gema)
	# Luz azul: contrasta con el naranja de la lava y llama la atención desde el
	# camino principal, invitando a desviarse.
	luz = OmniLight3D.new()
	luz.light_color = COLOR_AGUA
	luz.light_energy = 2.0
	luz.omni_range = 4.0
	add_child(luz)
	sonido = AudioStreamPlayer3D.new()
	sonido.stream = preload("res://assets/audio/orbe.wav")
	sonido.bus = &"SFX"
	sonido.pitch_scale = 1.5
	add_child(sonido)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if tomado:
		return
	tiempo += delta
	gema.rotation.y += delta * 1.5
	gema.position.y = 0.25 + sin(tiempo * 2.0) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if tomado or not body.is_in_group("jugador"):
		return
	tomado = true
	body.salud.curar(body.salud.maximo * recuperacion)
	sonido.play()
	recogido.emit(self)
	# Feedback: la gema se agranda y se desvanece; la luz se apaga.
	var tween := create_tween().set_parallel()
	tween.tween_property(gema, "scale", Vector3.ONE * 2.2, 0.35)
	tween.tween_property(gema, "transparency", 1.0, 0.35)
	tween.tween_property(luz, "light_energy", 0.0, 0.35)
	tween.chain().tween_interval(0.6) # deja terminar el sonido
	tween.chain().tween_callback(queue_free)
