extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

# Cámara
const THIRD_PERSON_DISTANCE = 4.0
const TOGGLE_VIEW_KEY = KEY_V

# Movimiento: aceleración y frenado progresivos (m/s² aprox.)
const ACCEL_GROUND = 40.0
const ACCEL_AIR = 12.0

# Salto: caída más rápida que la subida y salto variable
const FALL_GRAVITY_MULT = 1.6
const JUMP_CUT = 0.5

# Ventanas de tolerancia (segundos)
const COYOTE_TIME = 0.12
const JUMP_BUFFER_TIME = 0.12

# Duración de la animación de recoger o colocar (segundos)
const GRAB_TIME_IN = 0.2
const GRAB_TIME_OUT = 0.3

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var first_person := false
var objeto_llevado := ""

var grab_amount := 0.0
var viento := Vector3.ZERO
var viento_restante := 0.0
var was_on_floor := true

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var visual = $Visual  # nodo con script personaje.gd (método animar)

func _physics_process(delta: float) -> void:
	# Coyote time: permite saltar un instante después de caer de un borde.
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	# Jump buffer: recuerda la pulsación de salto un instante antes de tocar suelo.
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	# Gravedad: al caer se aplica más fuerza para que el salto no flote.
	if not is_on_floor():
		var g := get_gravity()
		if velocity.y < 0:
			g *= FALL_GRAVITY_MULT
		velocity += g * delta

	# Ejecutar el salto si hay pulsación guardada y coyote time activo.
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# Salto variable: soltar el botón antes corta la subida.
	if Input.is_action_just_released("ui_accept") and velocity.y > 0:
		velocity.y *= JUMP_CUT

	# Movimiento relativo a la orientación del cuerpo (que gira con el ratón).
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_x := direction.x * SPEED
	var target_z := direction.z * SPEED

	# Aceleración más suave en el aire para que el control sea más natural.
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	velocity.x = move_toward(velocity.x, target_x, accel * delta)
	velocity.z = move_toward(velocity.z, target_z, accel * delta)

	if viento_restante > 0.0:
		velocity += viento * delta
		viento_restante -= delta

	move_and_slide()

	_update_animation(delta)


func _update_animation(delta: float) -> void:
	var grounded := is_on_floor()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()

	# Las articulaciones se animan dentro del personaje.
	visual.animar(horizontal_speed, grounded, grab_amount, delta)

	# Aterrizaje: aplastamiento breve que vuelve a la escala normal.
	if grounded and not was_on_floor:
		visual.scale = Vector3(1.1, 0.85, 1.1)
	visual.scale = visual.scale.lerp(Vector3.ONE, 8.0 * delta)
	was_on_floor = grounded


# Llamado por las zonas de viento. La aceleración se mantiene durante 'duracion' segundos.
func aplicar_viento(aceleracion: Vector3, duracion: float) -> void:
	viento = aceleracion
	viento_restante = duracion


# Llamado por los altares al recoger o colocar un objeto.
func play_grab() -> void:
	var tw := create_tween()
	tw.tween_property(self, "grab_amount", 1.0, GRAB_TIME_IN)
	tw.tween_property(self, "grab_amount", 0.0, GRAB_TIME_OUT)


func _ready():
	add_to_group("jugador")
	_apply_camera_mode()


func _unhandled_input(event):
	# V alterna entre primera y tercera persona.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_VIEW_KEY:
		first_person = not first_person
		_apply_camera_mode()

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Girar todo el cuerpo a la izquierda o derecha (la cámara lo sigue).
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

		# Inclinar solo el pivote de la cámara arriba o abajo.
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-60), deg_to_rad(30))


func _apply_camera_mode() -> void:
	# En primera persona la cámara va pegada al pivote (a la altura de la cabeza)
	# y el personaje se oculta para no tapar la vista.
	spring_arm.spring_length = 0.0 if first_person else THIRD_PERSON_DISTANCE
	visual.visible = not first_person
