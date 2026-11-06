extends Node

# Autoload "Dispositivo": recuerda si el jugador usó por última vez el mando o el
# teclado/ratón, para que los textos en pantalla muestren el botón correcto
# ("[E]" en teclado, "[Botón X]" en mando) y no se confundan entre sí.

signal cambiado(usando_mando: bool)

const UMBRAL_STICK := 0.5 # ignora el ruido de un stick en reposo

var usando_mando := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var mando := usando_mando
	if event is InputEventJoypadButton:
		mando = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > UMBRAL_STICK:
		mando = true
	elif event is InputEventKey or event is InputEventMouseButton:
		mando = false
	if mando != usando_mando:
		usando_mando = mando
		cambiado.emit(usando_mando)


# Devuelve el texto que corresponde al dispositivo en uso.
func texto(teclado: String, mando: String) -> String:
	return mando if usando_mando else teclado
