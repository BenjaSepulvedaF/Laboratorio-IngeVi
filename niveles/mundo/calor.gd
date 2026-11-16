extends Node

# Calor del volcán: mientras se juega, quema la salud del jugador de forma
# constante. Obliga a avanzar: no basta con no caerse, hay que ir rápido.
# En las zonas de viento quema más (el viento arrastra aire ardiente), así que
# quedarse agachado esperando a que pasen las ráfagas tiene un costo.
# Lo enciende y apaga partida.gd: solo quema en el estado JUGANDO.

# Segundos que dura la barra llena sin recuperarse. Es el valor que más
# cambia la dificultad: ajustarlo jugando.
@export var segundos_de_resistencia := 90.0
@export var multiplicador_viento := 2.0

var activo := false
var salud: Salud


func _physics_process(delta: float) -> void:
	if not activo or salud == null:
		return
	var por_segundo := salud.maximo / segundos_de_resistencia
	if _en_zona_de_viento():
		por_segundo *= multiplicador_viento
	# Daño en unidades por segundo, multiplicado por delta: quema lo mismo a
	# cualquier tasa de fotogramas.
	salud.danar(por_segundo * delta, "calor")


# Se consulta el grupo cada vez (son solo tres zonas) en lugar de guardarlo en
# _ready: este nodo está antes que el Parkour en la escena, así que en su _ready
# las zonas todavía no se han registrado en el grupo.
func _en_zona_de_viento() -> bool:
	for zona in get_tree().get_nodes_in_group("zonas_viento"):
		if zona.jugador != null:
			return true
	return false
