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

signal orbe_entregado(id: String)

const NIVELES := [
	{"id": "volcan", "nombre": "El corazón del volcán", "orbe": "Orbe del volcán"},
	# {"id": "cueva", "nombre": "La cueva", "orbe": "Orbe de la cueva"},
]

var entregados: Array[String] = []


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
