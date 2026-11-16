extends CharacterBody3D

signal caida
signal agarre_cambiado(activo: bool)

enum Estado { NORMAL, COLGADO, ESCALANDO, BLOQUEADO }
const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003
# Giro de cámara con el stick derecho del mando, en radianes por segundo.
const VELOCIDAD_CAMARA_MANDO := 2.6
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
# Caídas más lentas que esto (bajar un escalón) no suenan al aterrizar.
const VELOCIDAD_ATERRIZAJE_AUDIBLE := 2.5

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
var velocidad_caida := 0.0
# Agachado no es un Estado aparte: es una variante de NORMAL. Así el resto del juego
# (partida, altares, pruebas) sigue tratando al jugador como "en pie y activo".
var agachado := false
var tween_agarre: Tween
# Cuerpo del que está colgado: si es una plataforma inestable que cae, lo suelta.
var borde_agarrado: Node3D = null

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var visual = $Visual
@onready var colision: CollisionShape3D = $CollisionShape3D
@onready var salud: Salud = $Salud
@onready var sonido_salto: AudioStreamPlayer = $Sonidos/Salto
@onready var sonido_aterrizaje: AudioStreamPlayer = $Sonidos/Aterrizaje
@onready var sonido_agarre: AudioStreamPlayer = $Sonidos/Agarre
@onready var sonido_escalada: AudioStreamPlayer = $Sonidos/Escalada
@onready var sonido_orbe: AudioStreamPlayer = $Sonidos/Orbe
# Su process_mode es Always: al morir se pausa el juego y un sonido normal quedaría congelado.
@onready var sonido_muerte: AudioStreamPlayer = $Sonidos/Muerte
@onready var sonido_agacharse: AudioStreamPlayer = $Sonidos/Agacharse
# También Always: sigue sonando cuando aparece el menú de victoria (juego en pausa).
@onready var sonido_entrega: AudioStreamPlayer = $Sonidos/Entrega


func _ready() -> void:
	add_to_group("jugador")
	ultima_posicion_suelo = global_position
	spring_arm.add_excluded_object(get_rid())
	_apply_camera_mode()


# delta es el tiempo (en segundos) desde el último tick de física. La física corre
# a tasa fija (60 por defecto), así que delta es casi constante. Todas las velocidades
# y aceleraciones están en unidades por segundo y se multiplican por delta, por lo que
# el movimiento no depende del framerate.
func _physics_process(delta: float) -> void:
	bloqueo_agarre = maxf(0.0, bloqueo_agarre - delta)
	match estado:
		Estado.NORMAL:
			_mover_normal(delta)
		Estado.COLGADO:
			if Input.is_action_just_pressed("mover_atras"):
				_soltarse()
			elif Input.is_action_just_pressed("saltar"):
				_iniciar_escalada()
		Estado.ESCALANDO:
			_escalar(delta)
	if estado != Estado.BLOQUEADO:
		# El stick es un valor continuo (no un evento), así que se lee cada tick y se
		# multiplica por delta: la cámara gira lo mismo por segundo a cualquier tasa.
		var mirar := Input.get_vector("camara_izquierda", "camara_derecha", "camara_arriba", "camara_abajo")
		if mirar != Vector2.ZERO:
			_girar_camara(mirar * VELOCIDAD_CAMARA_MANDO * delta)
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
		# Los temporizadores restan segundos reales: su duración no depende de los FPS.
		coyote_timer -= delta
	_actualizar_agachado()
	if agachado:
		_mover_agachado(delta)
		return
	if Input.is_action_just_pressed("saltar"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta
	if not is_on_floor():
		var gravedad := get_gravity()
		if velocity.y < 0:
			gravedad *= FALL_GRAVITY_MULT
		# La gravedad está en m/s². Multiplicarla por delta suma la velocidad de este tick.
		velocity += gravedad * delta
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		# Feedback del salto: sonido y estirón del cuerpo en el mismo tick del impulso.
		_reproducir(sonido_salto)
		visual.scale = Vector3(0.9, 1.15, 0.9)
	if Input.is_action_just_released("saltar") and velocity.y > 0:
		velocity.y *= JUMP_CUT
	var entrada := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	var direccion := global_basis * Vector3(entrada.x, 0, entrada.y)
	# La aceleración está en m/s². Con delta, cada tick cambia la velocidad solo lo que
	# corresponde a ese tiempo: a 30 o 144 FPS se llega a la misma velocidad en el mismo tiempo.
	var aceleracion := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	velocity.x = move_toward(velocity.x, direccion.x * SPEED, aceleracion * delta)
	velocity.z = move_toward(velocity.z, direccion.z * SPEED, aceleracion * delta)
	# Las ráfagas también son aceleraciones (m/s²), así que se integran con delta.
	if viento_restante > 0:
		velocidad_viento += viento * delta
		viento_restante -= delta
	else:
		velocidad_viento = velocidad_viento.move_toward(Vector3.ZERO, 6.0 * delta)
	velocity += velocidad_viento
	# Se guarda antes de moverse: al tocar el suelo, move_and_slide() anula velocity.y.
	velocidad_caida = -velocity.y
	# move_and_slide() usa velocity en m/s y ya aplica el desplazamiento de este tick.
	move_and_slide()
	if not is_on_floor() and velocity.y <= 0.0 and bloqueo_agarre <= 0.0:
		_buscar_borde()


# Agacharse solo se puede en el suelo. Si se mantiene el botón en el aire, el
# jugador se agacha apenas aterriza.
func _actualizar_agachado() -> void:
	var quiere := Input.is_action_pressed("agacharse") and is_on_floor()
	if quiere and not agachado:
		agachado = true
		# Agarrarse al suelo corta en seco cualquier empuje que ya estuviera actuando.
		viento = Vector3.ZERO
		viento_restante = 0.0
		velocidad_viento = Vector3.ZERO
		jump_buffer_timer = 0.0
		_reproducir(sonido_agacharse)
	elif not quiere and agachado:
		agachado = false


# Agachado: inmune a empujes, a cambio de no poder caminar ni saltar.
func _mover_agachado(delta: float) -> void:
	# Frena con la misma aceleración del suelo (m/s², por eso se multiplica por delta).
	velocity.x = move_toward(velocity.x, 0.0, ACCEL_GROUND * delta)
	velocity.z = move_toward(velocity.z, 0.0, ACCEL_GROUND * delta)
	velocidad_caida = -velocity.y
	move_and_slide()


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
		borde_agarrado = pared.collider
		estado = Estado.COLGADO
		was_on_floor = false
		agarre_cambiado.emit(true)
		_reproducir(sonido_agarre)
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
	_reproducir(sonido_escalada)


func _escalar(delta: float) -> void:
	# delta / DURACION_ESCALADA es la fracción de la escalada que cubre este tick.
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


# Para objetos externos: una plataforma que se derrumba suelta al jugador colgado.
func soltar_borde() -> void:
	if estado == Estado.COLGADO or estado == Estado.ESCALANDO:
		_soltarse()


func _soltarse() -> void:
	borde_agarrado = null
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
	velocidad_caida = 0.0
	agachado = false


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


## Punto de entrada único para cualquier empuje externo (viento, y a futuro
## explosiones, enemigos, etc.). Devuelve false si el jugador no puede ser
## empujado: colgado, escalando, bloqueado o agachado.
func aplicar_empuje(aceleracion: Vector3, duracion: float) -> bool:
	if estado != Estado.NORMAL or agachado:
		return false
	viento = aceleracion
	viento_restante = duracion
	return true


func aplicar_viento(aceleracion: Vector3, duracion: float) -> bool:
	return aplicar_empuje(aceleracion, duracion)


func play_grab() -> void:
	if tween_agarre:
		tween_agarre.kill()
	tween_agarre = create_tween()
	tween_agarre.tween_property(self, "grab_amount", 1.0, 0.2)
	tween_agarre.tween_property(self, "grab_amount", 0.0, 0.5)


func reproducir_orbe() -> void:
	_reproducir(sonido_orbe)


# Sin variar el tono: es melódico y desafinaría.
func reproducir_entrega() -> void:
	sonido_entrega.volume_db = -3.0
	sonido_entrega.pitch_scale = 1.0
	sonido_entrega.play()


# Baja el sonido de la entrega para que no se encime con la música de victoria.
func atenuar_entrega() -> void:
	if not sonido_entrega.playing:
		return
	var tween := sonido_entrega.create_tween()
	tween.tween_property(sonido_entrega, "volume_db", -40.0, 0.5)
	tween.tween_callback(sonido_entrega.stop)


# La llama partida.gd al morir, sea por tocar la lava o por caer fuera del mapa.
func reproducir_muerte() -> void:
	_reproducir(sonido_muerte)


# Variar levemente el tono evita que un sonido repetido muchas veces suene
# idéntico y canse al oído.
func _reproducir(sonido: AudioStreamPlayer) -> void:
	sonido.pitch_scale = randf_range(0.92, 1.08)
	sonido.play()


func _update_animation(delta: float) -> void:
	var apoyado := is_on_floor()
	var velocidad_horizontal := Vector2(velocity.x, velocity.z).length()
	var pose_borde := 1 if estado == Estado.COLGADO else (2 if estado == Estado.ESCALANDO else 0)
	if agachado and estado == Estado.NORMAL:
		pose_borde = 3
	visual.animar(velocidad_horizontal, apoyado or estado == Estado.BLOQUEADO, grab_amount, delta, pose_borde, progreso_escalada)
	if estado == Estado.NORMAL and apoyado and not was_on_floor:
		# Feedback del aterrizaje: aplastamiento del cuerpo y sonido en el mismo tick.
		visual.scale = Vector3(1.1, 0.85, 1.1)
		if velocidad_caida > VELOCIDAD_ATERRIZAJE_AUDIBLE:
			_reproducir(sonido_aterrizaje)
	visual.scale = visual.scale.lerp(Vector3.ONE, minf(1.0, 8.0 * delta))
	was_on_floor = apoyado


func _unhandled_input(event: InputEvent) -> void:
	if estado == Estado.BLOQUEADO:
		return
	if event.is_action_pressed("cambiar_camara"):
		first_person = not first_person
		_apply_camera_mode()
	# El ratón entrega desplazamientos (no un valor continuo como el stick), por eso
	# se lee como evento y no como acción del InputMap.
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_girar_camara(event.relative * MOUSE_SENSITIVITY)


# Giro en radianes, compartido por ratón y stick derecho.
func _girar_camara(giro: Vector2) -> void:
	if estado == Estado.NORMAL:
		rotate_y(-giro.x)
	else:
		camera_pivot.rotation.y = clampf(camera_pivot.rotation.y - giro.x, -1.1, 1.1)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - giro.y, deg_to_rad(-65), deg_to_rad(45))


func _apply_camera_mode() -> void:
	spring_arm.spring_length = 0.0 if first_person else THIRD_PERSON_DISTANCE
	visual.visible = not first_person
