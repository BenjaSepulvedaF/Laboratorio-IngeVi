extends CanvasLayer

# Menús del juego: pantalla de inicio y pausa (ESC).
# Este nodo sigue funcionando mientras el juego está pausado.

enum Estado { INICIO, JUGANDO, PAUSA }

var estado := Estado.INICIO
var fondo: ColorRect
var titulo: Label
var boton_principal: Button
var boton_salir: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_construir()
	_mostrar(Estado.INICIO)


func _construir() -> void:
	fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)

	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(320, 0)
	caja.add_theme_constant_override("separation", 14)
	centro.add_child(caja)

	titulo = Label.new()
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 36)
	caja.add_child(titulo)

	boton_principal = Button.new()
	boton_principal.custom_minimum_size = Vector2(0, 48)
	boton_principal.pressed.connect(_on_principal_pressed)
	caja.add_child(boton_principal)

	boton_salir = Button.new()
	boton_salir.custom_minimum_size = Vector2(0, 48)
	boton_salir.text = "Salir"
	boton_salir.pressed.connect(_on_salir_pressed)
	caja.add_child(boton_salir)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if estado == Estado.JUGANDO:
		_mostrar(Estado.PAUSA)
	elif estado == Estado.PAUSA:
		_reanudar()
	get_viewport().set_input_as_handled()


func _mostrar(nuevo: Estado) -> void:
	estado = nuevo
	visible = true
	fondo.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if estado == Estado.INICIO:
		titulo.text = "Lab Ingeniería Videojuegos"
		boton_principal.text = "Jugar"
	else:
		titulo.text = "Pausa"
		boton_principal.text = "Continuar"


func _reanudar() -> void:
	estado = Estado.JUGANDO
	fondo.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_principal_pressed() -> void:
	_reanudar()


func _on_salir_pressed() -> void:
	get_tree().quit()
