extends RigidBody3D

# Plataforma inestable: un RigidBody3D que empieza congelado (freeze) y se comporta
# como un apoyo sólido. Al pisarla o colgarse de ella tiembla un momento y luego se
# descongela: desde ahí la mueve el motor de física (gravedad, masa, rotación), no
# este script. Unos segundos después reaparece en su sitio para que el recorrido
# (y el regreso con el orbe) siga siendo posible.
#
# Se colocan bajo las zonas de viento: agacharse protege del viento, pero no de
# que la plataforma se caiga, así que el jugador no puede quedarse quieto.

enum Fase { ESTABLE, TEMBLANDO, CAYENDO, OCULTA }

const TIEMPO_AVISO := 1.5 # segundos de temblor antes de caer
const TIEMPO_REAPARICION := 3.5 # desde que empieza a caer
const AMPLITUD_TEMBLOR := 0.06
const ALTURA_OCULTAR := -6.0
# Capas: 1 sólido + 2 agarrable mientras está estable; al caer solo sólido (no se
# puede agarrar una plataforma que se desploma) y sin máscara (atraviesa lo demás).
const CAPAS_ESTABLE := 3
const MASCARA_ESTABLE := 4
const CAPAS_CAYENDO := 1
const COLOR_GRIETAS := Color(1.0, 0.35, 0.08)
# Sonidos opcionales: si existen estos archivos se usan; si no, un sustituto.
const RUTAS_CRUJIDO := ["res://assets/audio/crujido.wav", "res://assets/audio/crujido.mp3", "res://assets/audio/crujido.ogg"]
const RUTAS_DERRUMBE := ["res://assets/audio/derrumbe.wav", "res://assets/audio/derrumbe.mp3", "res://assets/audio/derrumbe.ogg"]
const SUSTITUTO := preload("res://assets/audio/aterrizaje.wav")

var fase: Fase = Fase.ESTABLE
var tiempo := 0.0
var transform_original: Transform3D
var posicion_guardada := false
var visuales: Array[Node3D] = []
var posiciones_visuales: Array[Vector3] = []
var material_grietas: StandardMaterial3D
var sonido: AudioStreamPlayer3D
var stream_crujido: AudioStream
var stream_derrumbe: AudioStream
var jugador: CharacterBody3D


func _ready() -> void:
	add_to_group("inestables")
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	collision_layer = CAPAS_ESTABLE
	collision_mask = MASCARA_ESTABLE
	for hijo in get_children():
		if hijo is MeshInstance3D:
			visuales.append(hijo)
			posiciones_visuales.append(hijo.position)
	_crear_aspecto()
	stream_crujido = _cargar_primero(RUTAS_CRUJIDO)
	stream_derrumbe = _cargar_primero(RUTAS_DERRUMBE)
	sonido = AudioStreamPlayer3D.new()
	sonido.bus = &"SFX"
	sonido.unit_size = 8.0
	add_child(sonido)


# Grietas incandescentes: distinguen la plataforma antes de pisarla y se
# encienden mientras tiembla.
func _crear_aspecto() -> void:
	var roca := get_node_or_null("Roca") as MeshInstance3D
	if roca == null:
		return
	var base := roca.mesh.surface_get_material(0) as StandardMaterial3D
	material_grietas = base.duplicate() if base else StandardMaterial3D.new()
	material_grietas.albedo_color = material_grietas.albedo_color.darkened(0.25)
	material_grietas.emission_enabled = true
	material_grietas.emission = COLOR_GRIETAS
	material_grietas.emission_energy_multiplier = 0.35
	roca.material_override = material_grietas


func _cargar_primero(rutas: Array) -> AudioStream:
	for ruta in rutas:
		if ResourceLoader.exists(ruta):
			return load(ruta)
	return null


func _physics_process(delta: float) -> void:
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador")
		if jugador == null:
			return
	match fase:
		Fase.ESTABLE:
			if _jugador_encima() or _jugador_colgado():
				_empezar_temblor()
		Fase.TEMBLANDO:
			tiempo -= delta
			# El temblor solo mueve las mallas; el colisionador queda quieto para que
			# el jugador no resbale mientras decide saltar.
			var intensidad := 1.0 - tiempo / TIEMPO_AVISO
			for i in visuales.size():
				var sacudida := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1))
				visuales[i].position = posiciones_visuales[i] + sacudida * AMPLITUD_TEMBLOR * (0.4 + intensidad)
			if material_grietas:
				material_grietas.emission_energy_multiplier = lerpf(0.35, 2.5, intensidad)
			if tiempo <= 0.0:
				_soltar()
		Fase.CAYENDO, Fase.OCULTA:
			tiempo -= delta
			if fase == Fase.CAYENDO and global_position.y < ALTURA_OCULTAR:
				_ocultar()
			if tiempo <= 0.0 and not _jugador_en_el_hueco():
				_reaparecer()


func _jugador_encima() -> bool:
	if not jugador.is_on_floor():
		return false
	for i in jugador.get_slide_collision_count():
		if jugador.get_slide_collision(i).get_collider() == self:
			return true
	return false


func _jugador_colgado() -> bool:
	return jugador.borde_agarrado == self and jugador.estado != jugador.Estado.NORMAL


func _empezar_temblor() -> void:
	# La posición se guarda aquí y no en _ready: el generador del parkour coloca los
	# apoyos después de que los hijos ya están listos.
	if not posicion_guardada:
		transform_original = global_transform
		posicion_guardada = true
	fase = Fase.TEMBLANDO
	tiempo = TIEMPO_AVISO
	_sonar(stream_crujido, 0.75)


func _soltar() -> void:
	for i in visuales.size():
		visuales[i].position = posiciones_visuales[i]
	collision_layer = CAPAS_CAYENDO
	collision_mask = 0
	remove_from_group("agarrable")
	if _jugador_colgado():
		jugador.soltar_borde()
	# Desde aquí la física es del motor: freeze = false entrega el cuerpo a Jolt, que
	# integra la gravedad cada tick fijo. Solo se le da un giro inicial para que caiga
	# volcándose y no como un bloque perfectamente recto.
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3(randf_range(-1.2, 1.2), randf_range(-0.4, 0.4), randf_range(-1.2, 1.2))
	fase = Fase.CAYENDO
	tiempo = TIEMPO_REAPARICION
	_sonar(stream_derrumbe, 0.55)


func _ocultar() -> void:
	fase = Fase.OCULTA
	freeze = true
	visible = false
	collision_layer = 0


# Evita reaparecer dentro del jugador si justo está pasando por ese hueco.
func _jugador_en_el_hueco() -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = ($CollisionShape3D as CollisionShape3D).shape
	consulta.transform = transform_original
	consulta.collision_mask = MASCARA_ESTABLE
	consulta.margin = 0.3
	return not get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _reaparecer() -> void:
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = transform_original
	collision_layer = CAPAS_ESTABLE
	collision_mask = MASCARA_ESTABLE
	add_to_group("agarrable")
	visible = true
	if material_grietas:
		material_grietas.emission_energy_multiplier = 0.35
	fase = Fase.ESTABLE
	# Feedback visual: la plataforma "crece" en su sitio para que se note que volvió.
	for i in visuales.size():
		visuales[i].scale = Vector3.ONE * 0.05
		create_tween().tween_property(visuales[i], "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Vuelve al estado inicial al instante (sin animación). Lo usan las pruebas que
# revisan los bordes de cada apoyo, para las que el derrumbe no es el objetivo.
func restablecer() -> void:
	if fase == Fase.ESTABLE:
		return
	for i in visuales.size():
		visuales[i].position = posiciones_visuales[i]
	_reaparecer()
	for i in visuales.size():
		visuales[i].scale = Vector3.ONE


func _sonar(stream: AudioStream, tono_sustituto: float) -> void:
	if stream:
		sonido.stream = stream
		sonido.pitch_scale = randf_range(0.92, 1.08)
	else:
		sonido.stream = SUSTITUTO
		sonido.pitch_scale = tono_sustituto
	sonido.play()
