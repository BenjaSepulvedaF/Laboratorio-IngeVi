extends Node

# Autoload "Progreso": qué orbes se han colocado en el monumento del vestíbulo.
#
# Cada nivel guarda un orbe. Colocarlo en el monumento desbloquea el portal del
# nivel siguiente, y colocar el orbe del ÚLTIMO nivel de la lista es la victoria.
# Para agregar un nivel basta con sumarlo a NIVELES (en orden): el monumento crea
# su pedestal solo, y un portal con nivel_requerido = id del nivel anterior queda
# sellado hasta que se entregue ese orbe.
#
# El progreso dura mientras el juego está abierto (no se guarda en disco).
#
# También lleva el cronómetro del intento: empieza al entrar al nivel, sigue al
# cruzar el portal de vuelta (por eso vive aquí y no en una escena) y se detiene
# al colocar el orbe. Se detiene solo con el juego en pausa (menús).

signal orbe_entregado(id: String)
# Se emite una vez por segundo, no cada frame: el HUD solo reacciona a esto.
signal tiempo_cambiado(segundos: int)
signal cronometro_cambiado(activo: bool)

const NIVELES := [
	{"id": "volcan", "nombre": "El corazón del volcán", "orbe": "Orbe del volcán"},
	# {"id": "cueva", "nombre": "La cueva", "orbe": "Orbe de la cueva"},
]

var entregados: Array[String] = []
var tiempo := 0.0
var cronometro_activo := false
var tiempo_final := 0.0
var mejor_tiempo := 0.0 # 0 = todavía no hay


func _process(delta: float) -> void:
	if not cronometro_activo:
		return
	var antes := int(tiempo)
	tiempo += delta
	if int(tiempo) != antes:
		tiempo_cambiado.emit(int(tiempo))


# desde_cero: un reintento vuelve a 0. Si no, solo arranca si estaba detenido
# (al volver al nivel desde el vestíbulo, el intento sigue corriendo).
func iniciar_cronometro(desde_cero := false) -> void:
	if cronometro_activo and not desde_cero:
		return
	tiempo = 0.0
	cronometro_activo = true
	cronometro_cambiado.emit(true)
	tiempo_cambiado.emit(0)


func detener_cronometro() -> void:
	if not cronometro_activo:
		return
	cronometro_activo = false
	tiempo_final = tiempo
	if mejor_tiempo == 0.0 or tiempo_final < mejor_tiempo:
		mejor_tiempo = tiempo_final
	cronometro_cambiado.emit(false)


# Abandonar el intento (volver al vestíbulo desde un menú).
func cancelar_cronometro() -> void:
	cronometro_activo = false
	tiempo = 0.0
	cronometro_cambiado.emit(false)


static func formato(segundos: float) -> String:
	var total := int(segundos)
	return "%d:%02d" % [total / 60, total % 60]


func entregar(id: String) -> void:
	if id in entregados:
		return
	entregados.append(id)
	orbe_entregado.emit(id)


func entregado(id: String) -> bool:
	return id in entregados


# El primer nivel está abierto desde el inicio; los demás, cuando se entrega el
# orbe del nivel anterior.
func desbloqueado(id: String) -> bool:
	var indice := indice_de(id)
	return indice == 0 or (indice > 0 and entregado(NIVELES[indice - 1].id))


func es_ultimo(id: String) -> bool:
	return indice_de(id) == NIVELES.size() - 1


func completo() -> bool:
	return entregados.size() == NIVELES.size()


func indice_de(id: String) -> int:
	for i in NIVELES.size():
		if NIVELES[i].id == id:
			return i
	return -1


func datos(id: String) -> Dictionary:
	var indice := indice_de(id)
	return NIVELES[indice] if indice >= 0 else {}


func reiniciar() -> void:
	entregados.clear()
	cancelar_cronometro()
