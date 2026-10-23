@tool
extends Node3D

# Personaje articulado construido con primitivas (sin modelo externo).
# Cada articulación es un Node3D que rota: cuello, hombros, codos, caderas y rodillas.
# Jerarquía:
#   Visual (este nodo)
#    └ Pelvis
#       ├ Torso
#       │  ├ Cabeza
#       │  ├ BrazoIzq > AntebrazoIzq
#       │  └ BrazoDer > AntebrazoDer
#       ├ PiernaIzq > Pantorrilla izq
#       └ PiernaDer > Pantorrilla der

const COLOR_PIEL := Color(0.93, 0.74, 0.6)
const COLOR_CAMISA := Color(0.2, 0.45, 0.85)
const COLOR_PANTALON := Color(0.22, 0.2, 0.25)
const COLOR_ZAPATO := Color(0.1, 0.08, 0.06)
const COLOR_PELO := Color(0.25, 0.15, 0.08)
const ORBE = preload("res://orbe.tscn")

const PELVIS_Y := -0.09      # hace que los pies toquen el suelo (y = -1.0 del jugador)
const FREC_PASO := 1.6       # pasos por metro recorrido, aproximado
const SUAVIZADO := 12.0      # velocidad con la que las articulaciones llegan a su objetivo

var fase := 0.0
var pelvis: Node3D
var torso: Node3D
var cabeza: Node3D
var brazo_izq: Node3D
var brazo_der: Node3D
var antebrazo_izq: Node3D
var antebrazo_der: Node3D
var pierna_izq: Node3D
var pierna_der: Node3D
var pantorrilla_izq: Node3D
var pantorrilla_der: Node3D
var orbe_espalda: Node3D


func _ready() -> void:
	# Borra piezas de una construcción previa (por ejemplo, la del editor)
	# para no duplicarlas al ejecutar el juego.
	for hijo in get_children():
		hijo.free()

	pelvis = _articulacion(self, Vector3(0, PELVIS_Y, 0))
	_pieza(pelvis, Vector3(0.42, 0.2, 0.26), Vector3.ZERO, COLOR_PANTALON)

	torso = _articulacion(pelvis, Vector3(0, 0.1, 0))
	_pieza(torso, Vector3(0.5, 0.6, 0.28), Vector3(0, 0.3, 0), COLOR_CAMISA)
	orbe_espalda = ORBE.instantiate()
	orbe_espalda.name = "OrbeEspalda"
	orbe_espalda.position = Vector3(0, 0.34, 0.4)
	orbe_espalda.scale = Vector3.ONE * 0.8
	orbe_espalda.visible = false
	torso.add_child(orbe_espalda)

	cabeza = _articulacion(torso, Vector3(0, 0.6, 0))
	_pieza(cabeza, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.15, 0), COLOR_PIEL)
	_pieza(cabeza, Vector3(0.32, 0.1, 0.32), Vector3(0, 0.28, 0), COLOR_PELO)

	brazo_izq = _articulacion(torso, Vector3(-0.34, 0.55, 0))
	_pieza(brazo_izq, Vector3(0.14, 0.3, 0.14), Vector3(0, -0.15, 0), COLOR_CAMISA)
	antebrazo_izq = _articulacion(brazo_izq, Vector3(0, -0.3, 0))
	_pieza(antebrazo_izq, Vector3(0.12, 0.28, 0.12), Vector3(0, -0.14, 0), COLOR_PIEL)

	brazo_der = _articulacion(torso, Vector3(0.34, 0.55, 0))
	_pieza(brazo_der, Vector3(0.14, 0.3, 0.14), Vector3(0, -0.15, 0), COLOR_CAMISA)
	antebrazo_der = _articulacion(brazo_der, Vector3(0, -0.3, 0))
	_pieza(antebrazo_der, Vector3(0.12, 0.28, 0.12), Vector3(0, -0.14, 0), COLOR_PIEL)

	pierna_izq = _articulacion(pelvis, Vector3(-0.11, 0, 0))
	_pieza(pierna_izq, Vector3(0.18, 0.45, 0.18), Vector3(0, -0.225, 0), COLOR_PANTALON)
	pantorrilla_izq = _articulacion(pierna_izq, Vector3(0, -0.45, 0))
	_pieza(pantorrilla_izq, Vector3(0.16, 0.42, 0.16), Vector3(0, -0.21, 0), COLOR_PANTALON)
	_pieza(pantorrilla_izq, Vector3(0.2, 0.08, 0.3), Vector3(0, -0.42, 0.05), COLOR_ZAPATO)

	pierna_der = _articulacion(pelvis, Vector3(0.11, 0, 0))
	_pieza(pierna_der, Vector3(0.18, 0.45, 0.18), Vector3(0, -0.225, 0), COLOR_PANTALON)
	pantorrilla_der = _articulacion(pierna_der, Vector3(0, -0.45, 0))
	_pieza(pantorrilla_der, Vector3(0.16, 0.42, 0.16), Vector3(0, -0.21, 0), COLOR_PANTALON)
	_pieza(pantorrilla_der, Vector3(0.2, 0.08, 0.3), Vector3(0, -0.42, 0.05), COLOR_ZAPATO)


# Llamado desde jugador.gd cada frame.
# velocidad: velocidad horizontal en m/s.
# agarre: 0..1, para la animación de recoger o colocar el objeto.
func animar(velocidad: float, en_suelo: bool, agarre: float, delta: float, pose_borde: int = 0, progreso: float = 0.0) -> void:
	if pose_borde != 0:
		_animar_borde(delta, pose_borde == 2, progreso)
		return
	var caminando := en_suelo and velocidad > 0.5
	if caminando:
		fase += delta * velocidad * FREC_PASO
	var s := sin(fase) if caminando else 0.0
	var t := clampf(SUAVIZADO * delta, 0.0, 1.0)

	# Piernas: al caminar oscilan en oposición; en el aire se recogen.
	_acercar(pierna_izq, s * 0.6 if en_suelo else 0.7, t)
	_acercar(pierna_der, -s * 0.6 if en_suelo else 0.7, t)
	_acercar(pantorrilla_izq, -0.9 * maxf(0.0, -s) if en_suelo else -1.2, t)
	_acercar(pantorrilla_der, -0.9 * maxf(0.0, s) if en_suelo else -1.2, t)

	# Brazos: opuestos a la pierna del mismo lado; en el aire se levantan.
	_acercar(brazo_izq, -s * 0.5 if en_suelo else 1.5, t)
	_acercar(antebrazo_izq, 0.3 if en_suelo else 0.6, t)
	var brazo_der_base := s * 0.5 if en_suelo else 1.5
	_acercar(brazo_der, lerpf(brazo_der_base, 1.4, agarre), t)
	_acercar(antebrazo_der, lerpf(0.3, 1.0, agarre), t)

	# Torso y cadera: balanceo al caminar, inclinación al saltar y al agarrar.
	var inclinacion := 0.0 if en_suelo else -0.12
	torso.rotation.x = lerpf(torso.rotation.x, inclinacion + agarre * 0.3, t)
	torso.rotation.z = lerpf(torso.rotation.z, s * 0.05, t)
	var rebote := absf(s) * 0.04
	pelvis.position.y = lerpf(pelvis.position.y, PELVIS_Y + rebote, t)
	cabeza.rotation.x = lerpf(cabeza.rotation.x, 0.0, t)


func _animar_borde(delta: float, escalando: bool, progreso: float) -> void:
	var t := clampf(SUAVIZADO * delta, 0.0, 1.0)
	var esfuerzo := sin(progreso * PI) if escalando else 0.0
	_acercar(brazo_izq, 2.85 - esfuerzo * 1.1, t)
	_acercar(brazo_der, 2.85 - esfuerzo * 1.1, t)
	_acercar(antebrazo_izq, 0.15 + esfuerzo * 0.9, t)
	_acercar(antebrazo_der, 0.15 + esfuerzo * 0.9, t)
	_acercar(pierna_izq, 0.15 + esfuerzo * 0.9, t)
	_acercar(pierna_der, 0.05 + esfuerzo * 0.6, t)
	_acercar(pantorrilla_izq, -0.3 - esfuerzo * 0.6, t)
	_acercar(pantorrilla_der, -0.2 - esfuerzo * 0.5, t)
	torso.rotation.x = lerpf(torso.rotation.x, -0.08 + esfuerzo * 0.25, t)
	torso.rotation.z = lerpf(torso.rotation.z, 0.0, t)
	cabeza.rotation.x = lerpf(cabeza.rotation.x, -0.2, t)
	pelvis.position.y = lerpf(pelvis.position.y, PELVIS_Y, t)


func _acercar(n: Node3D, rx: float, t: float) -> void:
	n.rotation.x = lerpf(n.rotation.x, rx, t)


func _articulacion(padre: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	padre.add_child(n)
	return n


func _pieza(padre: Node3D, tam: Vector3, desplazamiento: Vector3, color: Color) -> void:
	var caja := BoxMesh.new()
	caja.size = tam
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	caja.material = mat
	var malla := MeshInstance3D.new()
	malla.mesh = caja
	malla.position = desplazamiento
	padre.add_child(malla)
