class_name Salud
extends Node

# Componente de salud reutilizable. No sabe QUÉ hace daño (calor, lava, y en la
# cueva enemigos): solo lleva la cuenta y avisa con señales. Quien quiera
# enterarse se conecta a ellas (patrón Observer): el HUD no consulta la salud
# cada frame, reacciona cuando esta le notifica un cambio.

signal cambiada(actual: float, maximo: float, diferencia: float)
signal agotada(causa: String)

@export var maximo := 100.0

var actual := maximo
var agotada_ya := false


func _ready() -> void:
	actual = maximo


func danar(cantidad: float, causa := "") -> void:
	if agotada_ya or cantidad <= 0.0:
		return
	_cambiar(actual - cantidad)
	if actual <= 0.0:
		agotada_ya = true
		agotada.emit(causa)


func curar(cantidad: float) -> void:
	if agotada_ya or cantidad <= 0.0:
		return
	_cambiar(actual + cantidad)


func llenar() -> void:
	curar(maximo)


# Daño letal sin importar la salud restante (por ejemplo, caer a la lava).
func vaciar(causa := "") -> void:
	danar(maximo, causa)


func fraccion() -> float:
	return actual / maximo


func _cambiar(nuevo: float) -> void:
	var anterior := actual
	actual = clampf(nuevo, 0.0, maximo)
	if not is_equal_approx(actual, anterior):
		cambiada.emit(actual, maximo, actual - anterior)
