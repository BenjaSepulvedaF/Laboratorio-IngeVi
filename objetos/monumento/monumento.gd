extends Node3D

# Monumento de los orbes, en el vestíbulo. Crea un pedestal por cada nivel de
# Progreso.NIVELES alrededor del monumento central. Quien llega con el orbe de un
# nivel lo coloca en su pedestal con "interactuar": el orbe viaja de la espalda
# al pedestal, se ilumina y Progreso registra la entrega.
# El cristal central brilla más a medida que se completan los orbes.

signal entrega_terminada(id: String)

const ORBE = preload("res://objetos/orbe/orbe.tscn")
const RADIO := 3.3 # distancia de los pedestales al centro del monumento
const SEPARACION_ANGULAR := 0.8 # radianes entre pedestales
const ALTO_PEDESTAL := 1.0

@export var cristal_central: NodePath
@export var luz_central: NodePath

var pedestales := {} # id -> {nodo, orbe, etiqueta}
var jugador_cerca: CharacterBody3D = null
var pedestal_cerca := ""
var entregando := false


func _ready() -> void:
	var total := Progreso.NIVELES.size()
	for i in total:
		var datos: Dictionary = Progreso.NIVELES[i]
		# Los pedestales se reparten en un arco frente a la aparición del jugador (+z).
		var angulo := (i - (total - 1) * 0.5) * SEPARACION_ANGULAR
		var posicion := Vector3(sin(angulo), 0, cos(angulo)) * RADIO
		_crear_pedestal(datos, posicion)
	Progreso.orbe_entregado.connect(func(_id): _actualizar_cristal())
	_actualizar_cristal()


func _crear_pedestal(datos: Dictionary, posicion: Vector3) -> void:
	var raiz := Node3D.new()
	raiz.name = "Pedestal_" + datos.id
	raiz.position = posicion
	add_child(raiz)
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = 0.45
	cilindro.height = ALTO_PEDESTAL
	forma.shape = cilindro
	forma.position.y = ALTO_PEDESTAL * 0.5
	cuerpo.add_child(forma)
	var malla := MeshInstance3D.new()
	var columna := CylinderMesh.new()
	columna.top_radius = 0.42
	columna.bottom_radius = 0.5
	columna.height = ALTO_PEDESTAL
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = Color(0.32, 0.29, 0.3)
	piedra.roughness = 0.85
	columna.material = piedra
	malla.mesh = columna
	malla.position.y = ALTO_PEDESTAL * 0.5
	cuerpo.add_child(malla)
	raiz.add_child(cuerpo)
	# Hueco brillante sobre el pedestal: indica dónde va el orbe.
	var hueco := MeshInstance3D.new()
	var anillo := TorusMesh.new()
	anillo.inner_radius = 0.22
	anillo.outer_radius = 0.3
	var brillo := StandardMaterial3D.new()
	brillo.albedo_color = Color(1, 0.55, 0.2)
	brillo.emission_enabled = true
	brillo.emission = Color(1, 0.45, 0.1)
	brillo.emission_energy_multiplier = 1.5
	anillo.material = brillo
	hueco.mesh = anillo
	hueco.position.y = ALTO_PEDESTAL + 0.02
	raiz.add_child(hueco)
	var orbe := ORBE.instantiate()
	orbe.position.y = ALTO_PEDESTAL + 0.45
	orbe.visible = Progreso.entregado(datos.id)
	raiz.add_child(orbe)
	var etiqueta := Label3D.new()
	etiqueta.position.y = ALTO_PEDESTAL + 1.2
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.font_size = 32
	etiqueta.outline_size = 10
	etiqueta.modulate = Color(1, 0.85, 0.6)
	raiz.add_child(etiqueta)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 4 # jugador
	var zona := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 1.7
	zona.shape = esfera
	zona.position.y = 1.0
	area.add_child(zona)
	area.body_entered.connect(_on_entrar.bind(datos.id))
	area.body_exited.connect(_on_salir.bind(datos.id))
	raiz.add_child(area)
	pedestales[datos.id] = {"nodo": raiz, "orbe": orbe, "etiqueta": etiqueta}
	_actualizar_etiqueta(datos.id)
	Dispositivo.cambiado.connect(func(_mando): _actualizar_etiqueta(datos.id))


func _on_entrar(body: Node3D, id: String) -> void:
	if body.is_in_group("jugador"):
		jugador_cerca = body
		pedestal_cerca = id
		_actualizar_etiqueta(id)


func _on_salir(body: Node3D, id: String) -> void:
	if body == jugador_cerca and pedestal_cerca == id:
		jugador_cerca = null
		pedestal_cerca = ""
	_actualizar_etiqueta(id)


func _puede_entregar(id: String) -> bool:
	return not entregando and jugador_cerca != null and pedestal_cerca == id \
		and jugador_cerca.orbe_id == id and jugador_cerca.puede_interactuar() \
		and not Progreso.entregado(id)


func _actualizar_etiqueta(id: String) -> void:
	var datos := Progreso.datos(id)
	var etiqueta: Label3D = pedestales[id].etiqueta
	if Progreso.entregado(id):
		etiqueta.text = datos.orbe + "\n✔ Colocado"
	elif _puede_entregar(id):
		etiqueta.text = Dispositivo.texto("[E]", "[Botón X]") + " Colocar el " + datos.orbe.to_lower()
	else:
		etiqueta.text = datos.orbe + "\n" + datos.nombre


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interactuar") or not _puede_entregar(pedestal_cerca):
		return
	get_viewport().set_input_as_handled()
	_entregar(pedestal_cerca, jugador_cerca)


func _entregar(id: String, jugador: CharacterBody3D) -> void:
	entregando = true
	var destino: Node3D = pedestales[id].orbe
	jugador.bloquear()
	jugador.play_grab()
	jugador.reproducir_entrega()
	# Un orbe "en tránsito" vuela de la espalda al pedestal en un arco.
	var viajero := ORBE.instantiate()
	viajero.flotar = false
	add_child(viajero)
	var desde: Vector3 = jugador.posicion_orbe()
	var hasta := destino.global_position
	viajero.global_position = desde
	jugador.equipar_orbe(false)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		viajero.global_position = desde.lerp(hasta, t) + Vector3.UP * sin(t * PI) * 1.1,
		0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		viajero.queue_free()
		destino.visible = true
		destino.destellar()
		Progreso.entregar(id)
		entregando = false
		_actualizar_etiqueta(id)
		entrega_terminada.emit(id))


# El cristal central pasa de apagado a brillante según la fracción de orbes.
func _actualizar_cristal() -> void:
	var fraccion := float(Progreso.entregados.size()) / Progreso.NIVELES.size()
	var luz := get_node_or_null(luz_central) as OmniLight3D
	if luz:
		luz.light_energy = lerpf(0.6, 4.0, fraccion)
	var cristal := get_node_or_null(cristal_central) as CSGShape3D
	if cristal and cristal.material is StandardMaterial3D:
		var material := (cristal.material as StandardMaterial3D).duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission = Color(1, 0.5, 0.15)
		material.emission_energy_multiplier = lerpf(0.2, 3.0, fraccion)
		cristal.material = material
