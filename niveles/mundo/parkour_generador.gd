extends Node3D

# Coloca los apoyos del parkour de forma aleatoria cada vez que se entra al nivel.
# Apoyo01 queda fijo porque es el primer salto desde la isla inicial.
# Cada apoyo se coloca a una distancia y altura alcanzables desde el anterior, y la
# dificultad sube por sector (1: Apoyo01-08, 2: Apoyo09-16, 3: Apoyo17-24).
# semilla = -1 da un mapa distinto en cada entrada; un valor fijo lo repite.

@export var semilla := -1

const TOTAL_APOYOS := 24
const ALTURA_MINIMA := 2.5
const ALTURA_MAXIMA := 5.0
const ANCHO_MAXIMO := 6.5
const SEPARACION_MINIMA := 0.6
const INTENTOS := 200

# Por sector: distancia libre entre bordes, cambio de altura y giro máximo (radianes).
var distancia_por_sector := [Vector2(1.3, 1.9), Vector2(1.6, 2.3), Vector2(1.9, 2.7)]
var altura_por_sector := [Vector2(-0.2, 0.4), Vector2(-0.4, 0.5), Vector2(-0.5, 0.6)]
var giro_por_sector := [0.6, 0.8, 0.95]
# Índice (base 0) del apoyo donde se coloca cada zona de viento.
var indices_viento := {"ZonaViento1": 11, "ZonaViento2": 15, "ZonaViento3": 20}

var rng := RandomNumberGenerator.new()
var apoyos: Array[StaticBody3D] = []
var tamanos: Array[Vector3] = []
var alturas: Array[float] = []


func _ready() -> void:
	if semilla >= 0:
		rng.seed = semilla
	else:
		rng.randomize()
	for i in range(1, TOTAL_APOYOS + 1):
		var apoyo := get_node("Apoyo%02d" % i) as StaticBody3D
		apoyos.append(apoyo)
		tamanos.append((apoyo.get_node("CollisionShape3D").shape as BoxShape3D).size)
	alturas.append(apoyos[0].position.y + tamanos[0].y * 0.5)
	for i in range(1, TOTAL_APOYOS):
		_colocar(i)
	_colocar_altar_y_viento()


func _colocar(i: int) -> void:
	var sector := _sector(i)
	var distancia: Vector2 = distancia_por_sector[sector]
	var altura: Vector2 = altura_por_sector[sector]
	var giro: float = giro_por_sector[sector]
	var previo := apoyos[i - 1].position
	for intento in range(INTENTOS):
		var relajado := intento >= INTENTOS - 50
		var angulo := 0.0 if relajado else rng.randf_range(-giro, giro)
		var direccion := Vector3(sin(angulo), 0, -cos(angulo))
		var separacion := distancia.x if relajado else rng.randf_range(distancia.x, distancia.y)
		var centro := Vector2(previo.x, previo.z) + Vector2(direccion.x, direccion.z) * (separacion + _radio(i - 1, direccion) + _radio(i, direccion))
		var altura_nueva := alturas[i - 1] + (0.0 if relajado else rng.randf_range(altura.x, altura.y))
		if altura_nueva < ALTURA_MINIMA or altura_nueva > ALTURA_MAXIMA or absf(centro.x) > ANCHO_MAXIMO:
			continue
		if not relajado and _choca(i, centro):
			continue
		_asignar(i, centro, altura_nueva)
		return
	# Si ningún intento cumple, se coloca recto hacia delante con la distancia mínima.
	var recto := Vector3(0, 0, -1)
	var centro_recto := Vector2(previo.x, previo.z) + Vector2(recto.x, recto.z) * (distancia.x + _radio(i - 1, recto) + _radio(i, recto))
	_asignar(i, centro_recto, alturas[i - 1])


func _asignar(i: int, centro: Vector2, altura: float) -> void:
	apoyos[i].position = Vector3(centro.x, altura - tamanos[i].y * 0.5, centro.y)
	apoyos[i].set_meta("altura_superficie", altura)
	alturas.append(altura)


func _radio(i: int, direccion: Vector3) -> float:
	return absf(direccion.x) * tamanos[i].x * 0.5 + absf(direccion.z) * tamanos[i].z * 0.5


func _choca(i: int, centro: Vector2) -> bool:
	for j in range(i - 1):
		var otro := apoyos[j].position
		var dx := absf(otro.x - centro.x)
		var dz := absf(otro.z - centro.y)
		if dx < (tamanos[j].x + tamanos[i].x) * 0.5 + SEPARACION_MINIMA and dz < (tamanos[j].z + tamanos[i].z) * 0.5 + SEPARACION_MINIMA:
			return true
	return false


func _sector(i: int) -> int:
	if i < 8:
		return 0
	if i < 16:
		return 1
	return 2


func _colocar_altar_y_viento() -> void:
	var raiz := get_parent()
	var ultimo := apoyos[TOTAL_APOYOS - 1]
	var altar := raiz.get_node("AltarRecoger") as Node3D
	altar.position = Vector3(ultimo.position.x, alturas[TOTAL_APOYOS - 1], ultimo.position.z)
	for nombre in indices_viento:
		var indice: int = indices_viento[nombre]
		var zona := get_node(nombre) as Node3D
		zona.position = Vector3(apoyos[indice].position.x, alturas[indice] + 2.0, apoyos[indice].position.z)
