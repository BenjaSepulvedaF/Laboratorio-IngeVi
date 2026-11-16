extends Node3D

# Coloca los apoyos del parkour de forma aleatoria cada vez que se entra al nivel.
# Apoyo01 queda fijo porque es el primer salto desde la isla inicial.
# Cada apoyo se coloca a una distancia y altura alcanzables desde el anterior, y la
# dificultad sube por sector:
#   1: Apoyo01-08 (aprender)     2: Apoyo09-16 (viento e inestables)
#   3: Apoyo17-24 (saltos largos) -> Apoyo25: descanso amplio con un cristal
#   4: Apoyo26-32, el clímax: plataformas más pequeñas (precisión), saltos más
#      largos y dos inestables -> Torre del orbe: se sube colgándose de los bordes.
# Apoyo01-24 están en mundo.tscn; Apoyo25-32 y la torre se crean aquí por código.
# semilla = -1 da un mapa distinto en cada entrada; un valor fijo lo repite.

@export var semilla := -1

const APOYOS_EN_ESCENA := 24
const TOTAL_APOYOS := 32
const INDICE_DESCANSO := 24 # Apoyo25
const TAMANO_DESCANSO := Vector3(4.2, 0.8, 4.2)
const TAMANO_CLIMAX := Vector3(2.0, 0.8, 2.0)
# Índices (base 0) del sector 4 que son plataformas inestables.
const INESTABLES_CLIMAX := [27, 30] # Apoyo28 y Apoyo31
# Torre: cada piso sube más de lo que alcanza un salto (~1 m), así que solo se
# sube colgándose del borde del siguiente y escalando. Colgado, el cuerpo queda
# 2.05 m bajo el borde: con menos de ~2.1 m de subida chocaría con el piso de
# abajo y no podría colgarse. Con más de 3.2 m el borde no se alcanza.
const TORRE_PISOS := 5
const TORRE_SUBIDA := 2.3
# Separación entre pisos: cabe el jugador colgado (o escalando) entre dos pisos.
const TORRE_SEPARACION := 0.9
const TAMANO_PISO := Vector3(2.4, 0.8, 2.4)
# La cima es amplia: el pedestal del orbe ocupa ~1 m alrededor del centro.
const TAMANO_CIMA := Vector3(4.2, 0.8, 4.2)
const ALTURA_MINIMA := 2.5
const ALTURA_MAXIMA := 5.0
const ANCHO_MAXIMO := 6.5
const SEPARACION_MINIMA := 0.6
const INTENTOS := 200

# Por sector: distancia libre entre bordes, cambio de altura y giro máximo (radianes).
# Índice 3 = descanso (salto cómodo y llano), índice 4 = sector 4 (clímax).
var distancia_por_sector := [Vector2(1.3, 1.9), Vector2(1.6, 2.3), Vector2(1.9, 2.7), Vector2(1.6, 1.9), Vector2(2.0, 2.7)]
var altura_por_sector := [Vector2(-0.2, 0.4), Vector2(-0.4, 0.5), Vector2(-0.5, 0.6), Vector2(-0.1, 0.1), Vector2(-0.4, 0.6)]
var giro_por_sector := [0.6, 0.8, 0.95, 0.4, 1.0]
# Índice (base 0) del apoyo donde se coloca cada zona de viento. Esos apoyos
# (Apoyo12, Apoyo16 y Apoyo21) son las plataformas inestables en mundo.tscn.
var indices_viento := {"ZonaViento1": 11, "ZonaViento2": 15, "ZonaViento3": 20}

# Desvíos: callejones sin salida que salen del camino principal y terminan en un
# cristal de agua. Uno por sector, cada uno más exigente que el tramo que deja:
#   base: índice (base 0) del apoyo del que sale.
#   largo: cuántas plataformas tiene.
#   distancia / altura: separación entre bordes y subida por salto.
#   inestable: la última plataforma se derrumba (hay que tomar el cristal y salir).
var desvios := [
	{"base": 4, "largo": 2, "distancia": Vector2(2.0, 2.3), "altura": Vector2(0.0, 0.3), "inestable": false},
	{"base": 9, "largo": 2, "distancia": Vector2(2.1, 2.4), "altura": Vector2(0.0, 0.4), "inestable": true},
	{"base": 17, "largo": 3, "distancia": Vector2(2.3, 2.6), "altura": Vector2(0.2, 0.5), "inestable": false},
]
# Las columnas decorativas de paisaje.gd empiezan en |x| = 13 (radio hasta 1.3):
# con centro hasta 10 y medio ancho 1.5, el desvío nunca las toca.
const ANCHO_MAXIMO_DESVIO := 10.0
const CRISTAL = preload("res://objetos/cristal/cristal.gd")

var rng := RandomNumberGenerator.new()
# PhysicsBody3D: la mayoría son StaticBody3D y las plataformas inestables, RigidBody3D.
var apoyos: Array[PhysicsBody3D] = []
var tamanos: Array[Vector3] = []
var alturas: Array[float] = []


func _ready() -> void:
	if semilla >= 0:
		rng.seed = semilla
	else:
		rng.randomize()
	for i in range(1, APOYOS_EN_ESCENA + 1):
		apoyos.append(get_node("Apoyo%02d" % i) as PhysicsBody3D)
	_crear_apoyos_extra()
	for apoyo in apoyos:
		tamanos.append((apoyo.get_node("CollisionShape3D").shape as BoxShape3D).size)
	alturas.append(apoyos[0].position.y + tamanos[0].y * 0.5)
	for i in range(1, TOTAL_APOYOS):
		_colocar(i)
	for i in TOTAL_APOYOS:
		ocupados.append({"centro": Vector2(apoyos[i].position.x, apoyos[i].position.z), "tamano": tamanos[i]})
	_construir_torre()
	_colocar_altar_y_viento()
	_poner_cristal("CristalDescanso", apoyos[INDICE_DESCANSO].position, alturas[INDICE_DESCANSO])
	for i in desvios.size():
		_crear_desvio(i + 1, desvios[i])


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
	if i < INDICE_DESCANSO:
		return 2
	if i == INDICE_DESCANSO:
		return 3
	return 4


func _colocar_altar_y_viento() -> void:
	var raiz := get_parent()
	var cima := torre[torre.size() - 1]
	var altar := raiz.get_node("AltarRecoger") as Node3D
	altar.position = Vector3(cima.position.x, cima.get_meta("altura_superficie"), cima.position.z)
	for nombre in indices_viento:
		var indice: int = indices_viento[nombre]
		var zona := get_node(nombre) as Node3D
		zona.position = Vector3(apoyos[indice].position.x, alturas[indice] + 2.0, apoyos[indice].position.z)


# --- Desvíos -----------------------------------------------------------------

# Cuerpos ya ocupados (apoyos y plataformas de desvío) para no superponerse.
var ocupados: Array[Dictionary] = []
# Por cada desvío: [apoyo de salida, plataforma 1, ..., última]. Lo usan las pruebas.
var rutas_desvios: Array = []


func _crear_desvio(numero: int, datos: Dictionary) -> void:
	# Si no cabe desde su apoyo, se prueba desde los vecinos: el desvío sigue en
	# el mismo sector y el mapa siempre tiene sus tres cristales.
	for desplazamiento in [0, 1, -1, 2, -2]:
		var base: int = datos.base + desplazamiento
		# Dirección del camino en ese punto; el desvío sale hacia un costado.
		var avance := apoyos[base + 1].position - apoyos[base - 1].position
		avance.y = 0
		avance = avance.normalized()
		var lateral := Vector3(-avance.z, 0, avance.x)
		var lados := [1.0, -1.0] if rng.randf() < 0.5 else [-1.0, 1.0]
		for lado in lados:
			for intento in range(40):
				# Inclinación general del desvío: hacia delante o hacia atrás del camino.
				var direccion: Vector3 = (lateral * lado).rotated(Vector3.UP, rng.randf_range(-0.7, 0.7))
				var plan := _planear_desvio(base, direccion, avance, datos)
				if not plan.is_empty():
					_construir_desvio(numero, base, plan, datos)
					return
	push_warning("No cupo el desvío %d" % numero)


# Devuelve las posiciones (centro x/z y altura de la superficie) de cada
# plataforma, o un arreglo vacío si alguna choca o sale del área.
func _planear_desvio(base: int, direccion: Vector3, avance: Vector3, datos: Dictionary) -> Array:
	var plan := []
	var tamano := tamanos[base]
	var previo := Vector2(apoyos[base].position.x, apoyos[base].position.z)
	var altura_previa := alturas[base]
	var radio := tamano.x * 0.5
	for k in datos.largo:
		# Se abre en abanico: cada salto gira un poco hacia delante o atrás.
		var giro := rng.randf_range(-0.45, 0.45)
		var dir := direccion.rotated(Vector3.UP, giro)
		var paso: float = rng.randf_range(datos.distancia.x, datos.distancia.y) + radio * 2.0
		var centro := previo + Vector2(dir.x, dir.z) * paso
		var altura: float = altura_previa + rng.randf_range(datos.altura.x, datos.altura.y)
		if absf(centro.x) > ANCHO_MAXIMO_DESVIO or altura > ALTURA_MAXIMA + 1.0:
			return []
		for otro in ocupados:
			var dx := absf(otro.centro.x - centro.x)
			var dz := absf(otro.centro.y - centro.y)
			if dx < (otro.tamano.x + tamano.x) * 0.5 + SEPARACION_MINIMA and dz < (otro.tamano.z + tamano.z) * 0.5 + SEPARACION_MINIMA:
				return []
		for anterior in plan:
			if anterior.centro.distance_to(centro) < tamano.x + SEPARACION_MINIMA:
				return []
		plan.append({"centro": centro, "altura": altura})
		previo = centro
		altura_previa = altura
	return plan


func _construir_desvio(numero: int, base: int, plan: Array, datos: Dictionary) -> void:
	var ruta: Array = [apoyos[base]]
	for k in plan.size():
		var ultimo: bool = k == plan.size() - 1
		# Se copia un apoyo existente (malla, colisión y bordes agarrables). La
		# última plataforma del desvío inestable copia Apoyo12, que es RigidBody3D.
		var modelo: Node = get_node("Apoyo12") if ultimo and datos.inestable else apoyos[base]
		var plataforma := modelo.duplicate() as PhysicsBody3D
		plataforma.name = "Desvio%d_%d" % [numero, k + 1]
		plataforma.remove_from_group("apoyos")
		plataforma.add_to_group("desvios")
		var tamano := (plataforma.get_node("CollisionShape3D").shape as BoxShape3D).size
		plataforma.position = Vector3(plan[k].centro.x, plan[k].altura - tamano.y * 0.5, plan[k].centro.y)
		plataforma.set_meta("altura_superficie", plan[k].altura)
		add_child(plataforma)
		ruta.append(plataforma)
		ocupados.append({"centro": plan[k].centro, "tamano": tamano})
		if ultimo:
			_poner_cristal("Cristal%d" % numero, plataforma.position, plan[k].altura)
	rutas_desvios.append(ruta)


func _poner_cristal(nombre: String, sobre: Vector3, altura_superficie: float) -> void:
	var cristal := CRISTAL.new()
	cristal.name = nombre
	cristal.position = Vector3(sobre.x, altura_superficie + 1.0, sobre.z)
	add_child(cristal)


# --- Apoyos extra (descanso y sector 4) y torre ---------------------------------

var torre: Array[PhysicsBody3D] = []


func _crear_apoyos_extra() -> void:
	for i in range(APOYOS_EN_ESCENA, TOTAL_APOYOS):
		var tamano := TAMANO_DESCANSO if i == INDICE_DESCANSO else TAMANO_CLIMAX
		var modelo: Node = get_node("Apoyo12") if i in INESTABLES_CLIMAX else get_node("Apoyo20")
		var apoyo := _copiar_plataforma(modelo, "Apoyo%02d" % (i + 1), tamano)
		add_child(apoyo)
		apoyos.append(apoyo)


# Copia un apoyo de la escena (colisión, malla, cubierta, marca, grupos y script)
# con otro tamaño. Las formas y mallas se duplican: si no, cambiar el tamaño de
# la copia cambiaría también el del original.
func _copiar_plataforma(modelo: Node, nombre: String, tamano: Vector3) -> PhysicsBody3D:
	var copia := modelo.duplicate() as PhysicsBody3D
	copia.name = nombre
	var forma := BoxShape3D.new()
	forma.size = tamano
	(copia.get_node("CollisionShape3D") as CollisionShape3D).shape = forma
	var roca := copia.get_node("Roca") as MeshInstance3D
	var malla := roca.mesh.duplicate() as BoxMesh
	malla.size = tamano
	roca.mesh = malla
	var cubierta := copia.get_node_or_null("Cubierta") as MeshInstance3D
	if cubierta:
		var tapa := cubierta.mesh.duplicate() as BoxMesh
		tapa.size = Vector3(tamano.x + 0.02, tapa.size.y, tamano.z + 0.02)
		cubierta.mesh = tapa
		cubierta.position.y = tamano.y * 0.5
	var marca := copia.get_node_or_null("Marca") as Node3D
	if marca:
		marca.position = Vector3(0, tamano.y * 0.5 + 0.03, -(tamano.z * 0.5 - 0.55))
	return copia


# La torre sube en espiral desde el último apoyo: cada piso queda pegado al
# anterior (separación pequeña) y más alto de lo que se puede saltar. Los pisos
# son cajas alineadas a los ejes, así que la espiral también va por los ejes:
# así cada piso queda cara a cara con el siguiente.
func _construir_torre() -> void:
	var ultimo := apoyos[TOTAL_APOYOS - 1]
	var avance := ultimo.position - apoyos[TOTAL_APOYOS - 2].position
	var eje := Vector3(signf(avance.x), 0, 0) if absf(avance.x) > absf(avance.z) else Vector3(0, 0, signf(avance.z))
	# Salidas posibles: hacia delante o hacia un costado, nunca de vuelta.
	var salidas := [eje, eje.rotated(Vector3.UP, PI * 0.5), eje.rotated(Vector3.UP, -PI * 0.5)]
	var plan := []
	for salida in salidas:
		for sentido in [1.0, -1.0]:
			plan = _planear_torre(ultimo, salida, sentido)
			if not plan.is_empty():
				break
		if not plan.is_empty():
			break
	if plan.is_empty():
		push_warning("La torre no cupo sin superponerse; se construye igual.")
		plan = _planear_torre(ultimo, eje, 1.0, false)
	var altura := alturas[TOTAL_APOYOS - 1]
	for k in plan.size():
		var tamano: Vector3 = plan[k].tamano
		altura += TORRE_SUBIDA
		var piso := _copiar_plataforma(get_node("Apoyo20"), "Torre%d" % (k + 1), tamano)
		piso.remove_from_group("apoyos")
		piso.add_to_group("torre")
		piso.position = Vector3(plan[k].centro.x, altura - tamano.y * 0.5, plan[k].centro.y)
		piso.set_meta("altura_superficie", altura)
		add_child(piso)
		torre.append(piso)
		ocupados.append({"centro": plan[k].centro, "tamano": tamano})


func _planear_torre(desde: PhysicsBody3D, direccion: Vector3, sentido: float, revisar := true) -> Array:
	var plan := []
	var origen := Vector2(desde.position.x, desde.position.z)
	var previo := origen
	var radio_previo := (desde.get_node("CollisionShape3D").shape as BoxShape3D).size.x * 0.5
	var dir := direccion
	for k in TORRE_PISOS:
		var tamano := TAMANO_CIMA if k == TORRE_PISOS - 1 else TAMANO_PISO
		var centro := previo + Vector2(dir.x, dir.z) * (radio_previo + TORRE_SEPARACION + tamano.x * 0.5)
		if revisar:
			if absf(centro.x) > ANCHO_MAXIMO_DESVIO:
				return []
			for otro in ocupados:
				# El último apoyo es de donde sale la torre: está pegado a propósito.
				if otro.centro.is_equal_approx(origen):
					continue
				var dx := absf(otro.centro.x - centro.x)
				var dz := absf(otro.centro.y - centro.y)
				if dx < (otro.tamano.x + tamano.x) * 0.5 + SEPARACION_MINIMA and dz < (otro.tamano.z + tamano.z) * 0.5 + SEPARACION_MINIMA:
					return []
		plan.append({"centro": centro, "tamano": tamano})
		previo = centro
		radio_previo = tamano.x * 0.5
		# Espiral: cada piso gira 90° respecto del anterior.
		dir = dir.rotated(Vector3.UP, sentido * PI * 0.5).snappedf(1.0)
	return plan
