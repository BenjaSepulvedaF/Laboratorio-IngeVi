extends CharacterBody3D

signal caida
signal agarre_cambiado(activo: bool)

enum Estado { NORMAL, COLGADO, ESCALANDO, BLOQUEADO }
const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003
const THIRD_PERSON_DISTANCE := 4.0
const ACCEL_GROUND := 40.0
const ACCEL_AIR := 12.0
const FALL_GRAVITY_MULT := 1.6
const JUMP_CUT := 0.5
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
const DURACION_ESCALADA := 0.6
const BLOQUEO_REAGARRE := 0.4
const RADIO_CUERPO := 0.36
const ALTURA_MEDIA := 1.0
const MASCARA_BORDES := 2

var estado: Estado = Estado.NORMAL
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var first_person := false
var objeto_llevado := ""
var grab_amount := 0.0
var viento := Vector3.ZERO
var viento_restante := 0.0
var velocidad_viento := Vector3.ZERO
var was_on_floor := true
var bloqueo_agarre := 0.0
var progreso_escalada := 0.0
var punto_colgado := Vector3.ZERO
var punto_elevado := Vector3.ZERO
var punto_destino := Vector3.ZERO
var ultima_posicion_suelo := Vector3.ZERO
var tween_agarre: Tween

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var visual = $Visual
@onready var colision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("jugador")
	ultima_posicion_suelo = global_position
	spring_arm.add_excluded_object(get_rid())
	_apply_camera_mode()


func _physics_process(delta: float) -> void:
	bloqueo_agarre = maxf(0.0, bloqueo_agarre - delta)
	match estado:
		Estado.NORMAL:
			_mover_normal(delta)
		Estado.COLGADO:
			if Input.is_action_just_pressed("ui_down"):
				_soltarse()
			elif Input.is_action_just_pressed("ui_accept"):
				_iniciar_escalada()
		Estado.ESCALANDO:
			_escalar(delta)
	_update_animation(delta)
	if estado != Estado.BLOQUEADO and global_position.y < -8.0:
		caida.emit()


func _mover_normal(delta: float) -> void:
	# Separar el impulso externo evita que el frenado normal anule las ráfagas.
	velocity -= velocidad_viento
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		ultima_posicion_suelo = global_position
	else:
		coyote_timer -= delta
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta
	if not is_on_floor():
		var gravedad := get_gravity()
		if velocity.y < 0:
			gravedad *= FALL_GRAVITY_MULT
		velocity += gravedad * delta
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	if Input.is_action_just_released("ui_accept") and velocity.y > 0:
		velocity.y *= JUMP_CUT
	var entrada := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direccion := global_basis * Vector3(entrada.x, 0, entrada.y)
	var aceleracion := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	velocity.x = move_toward(velocity.x, direccion.x * SPEED, aceleracion * delta)
	velocity.z = move_toward(velocity.z, direccion.z * SPEED, aceleracion * delta)
	if viento_restante > 0:
		velocidad_viento += viento * delta
		viento_restante -= delta
	else:
		velocidad_viento = velocidad_viento.move_toward(Vector3.ZERO, 6.0 * delta)
	velocity += velocidad_viento
	move_and_slide()
	if not is_on_floor() and velocity.y <= 0.0 and bloqueo_agarre <= 0.0:
		_buscar_borde()


# Se consulta la pared y luego su cara superior. La máscara solo incluye apoyos.
func _buscar_borde() -> void:
	var direcciones: Array[Vector3] = []
	var regreso := ultima_posicion_suelo - global_position
	regreso.y = 0
	if regreso.length() > 0.05 and regreso.length() < 2.0:
		direcciones.append(regreso.normalized())
	for i in range(8):
		direcciones.append(Vector3(sin(i * TAU / 8.0), 0, cos(i * TAU / 8.0)))
	var espacio := get_world_3d().direct_space_state
	for direccion in direcciones:
		var desde := global_position + Vector3.UP * 0.4
		var pared := espacio.intersect_ray(_rayo(desde, desde + direccion * 0.85))
		if pared.is_empty() or absf(pared.normal.y) > 0.2:
			continue
		if not pared.collider.is_in_group("agarrable"):
			continue
		var normal: Vector3 = pared.normal
		# Alejar la muestra de la esquina evita rayos justo en el límite de dos
		# caras. El desplazamiento tangencial también deja apoyo para las manos.
		var anclaje: Vector3 = pared.position + direccion.slide(normal) * 0.3
		var interior: Vector3 = anclaje - normal * (RADIO_CUERPO + 0.18)
		var arriba := espacio.intersect_ray(_rayo(interior + Vector3.UP * 1.4, interior - Vector3.UP * 0.1))
		if arriba.is_empty() or arriba.collider != pared.collider or arriba.normal.y < 0.95:
			continue
		var alto: float = arriba.position.y
		var alcance := alto - global_position.y
		if alcance < 0.55 or alcance > 1.25:
			continue
		var colgado: Vector3 = anclaje + normal * (RADIO_CUERPO + 0.14)
		colgado.y = alto - 1.05
		var elevado := Vector3(colgado.x, alto + ALTURA_MEDIA + 0.025, colgado.z)
		var destino := elevado - normal * (RADIO_CUERPO * 2.0 + 0.33)
		if not _espacio_libre(colgado):
			continue
		if test_move(global_transform, colgado - global_position):
			continue
		punto_colgado = colgado
		punto_elevado = elevado
		punto_destino = destino
		global_position = colgado
		look_at(global_position - normal, Vector3.UP)
		camera_pivot.rotation.y = 0.0
		velocity = Vector3.ZERO
		_limpiar_impulsos()
		estado = Estado.COLGADO
		was_on_floor = false
		agarre_cambiado.emit(true)
		return


func _rayo(desde: Vector3, hasta: Vector3) -> PhysicsRayQueryParameters3D:
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta, MASCARA_BORDES, [get_rid()])
	consulta.collide_with_areas = false
	return consulta


func _espacio_libre(posicion: Vector3) -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = colision.shape
	consulta.transform = Transform3D(Basis.IDENTITY, posicion)
	consulta.collision_mask = collision_mask
	consulta.exclude = [get_rid()]
	consulta.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _iniciar_escalada() -> void:
	if estado != Estado.COLGADO or not _espacio_libre(punto_destino):
		return
	var desde := global_transform
	if test_move(desde, punto_elevado - global_position):
		return
	desde.origin = punto_elevado
	if test_move(desde, punto_destino - punto_elevado):
		return
	estado = Estado.ESCALANDO
	progreso_escalada = 0.0
	agarre_cambiado.emit(false)


func _escalar(delta: float) -> void:
	progreso_escalada = minf(1.0, progreso_escalada + delta / DURACION_ESCALADA)
	var objetivo: Vector3
	if progreso_escalada < 0.55:
		objetivo = punto_colgado.lerp(punto_elevado, smoothstep(0.0, 0.55, progreso_escalada))
	else:
		objetivo = punto_elevado.lerp(punto_destino, smoothstep(0.55, 1.0, progreso_escalada))
	if move_and_collide(objetivo - global_position) != null:
		# Una obstrucción nueva no debe hacer atravesar la plataforma.
		if _espacio_libre(punto_colgado):
			global_position = punto_colgado
			estado = Estado.COLGADO
			agarre_cambiado.emit(true)
		else:
			_soltarse()
		return
	if progreso_escalada >= 1.0:
		estado = Estado.NORMAL
		velocity = Vector3.ZERO
		bloqueo_agarre = BLOQUEO_REAGARRE
		camera_pivot.rotation.y = 0.0


func _soltarse() -> void:
	estado = Estado.NORMAL
	velocity = Vector3(0, -0.6, 0)
	bloqueo_agarre = BLOQUEO_REAGARRE
	camera_pivot.rotation.y = 0.0
	_limpiar_impulsos()
	agarre_cambiado.emit(false)


func _limpiar_impulsos() -> void:
	viento = Vector3.ZERO
	velocidad_viento = Vector3.ZERO
	viento_restante = 0.0
	coyote_timer = 0.0
	jump_buffer_timer = 0.0


func bloquear() -> void:
	estado = Estado.BLOQUEADO
	velocity = Vector3.ZERO
	_limpiar_impulsos()
	if tween_agarre:
		tween_agarre.kill()
	grab_amount = 0.0
	agarre_cambiado.emit(false)


func desbloquear() -> void:
	estado = Estado.NORMAL
	_limpiar_impulsos()


func puede_interactuar() -> bool:
	return estado == Estado.NORMAL


func equipar_orbe(equipado: bool) -> void:
	objeto_llevado = "Orbe Sagrado" if equipado else ""
	visual.orbe_espalda.visible = equipado


func posicion_orbe() -> Vector3:
	return visual.orbe_espalda.global_position


func aplicar_viento(aceleracion: Vector3, duracion: float) -> void:
	if estado == Estado.NORMAL:
		viento = aceleracion
		viento_restante = duracion


func play_grab() -> void:
	if tween_agarre:
		tween_agarre.kill()
	tween_agarre = create_tween()
	tween_agarre.tween_property(self, "grab_amount", 1.0, 0.2)
	tween_agarre.tween_property(self, "grab_amount", 0.0, 0.5)


func _update_animation(delta: float) -> void:
	var apoyado := is_on_floor()
	var velocidad_horizontal := Vector2(velocity.x, velocity.z).length()
	var pose_borde := 1 if estado == Estado.COLGADO else (2 if estado == Estado.ESCALANDO else 0)
	visual.animar(velocidad_horizontal, apoyado or estado == Estado.BLOQUEADO, grab_amount, delta, pose_borde, progreso_escalada)
	if estado == Estado.NORMAL and apoyado and not was_on_floor:
		visual.scale = Vector3(1.1, 0.85, 1.1)
	visual.scale = visual.scale.lerp(Vector3.ONE, minf(1.0, 8.0 * delta))
	was_on_floor = apoyado


func _unhandled_input(event: InputEvent) -> void:
	if estado == Estado.BLOQUEADO:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		first_person = not first_person
		_apply_camera_mode()
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if estado == Estado.NORMAL:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		else:
			camera_pivot.rotation.y = clampf(camera_pivot.rotation.y - event.relative.x * MOUSE_SENSITIVITY, -1.1, 1.1)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-65), deg_to_rad(45))


func _apply_camera_mode() -> void:
	spring_arm.spring_length = 0.0 if first_person else THIRD_PERSON_DISTANCE
	visual.visible = not first_person
