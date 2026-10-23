extends CanvasLayer

signal jugar_solicitado
signal reinicio_solicitado
signal pausa_solicitada

var fondo: ColorRect
var titulo: Label
var descripcion: Label
var boton_principal: Button
var objetivo: Label
var ayuda_borde: Label
var hud: MarginContainer
var menu_actual := "INICIO"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_construir()


func _texto(contenido: String, tamano: int, color: Color) -> Label:
	var texto := Label.new()
	texto.text = contenido
	texto.add_theme_font_size_override("font_size", tamano)
	texto.add_theme_color_override("font_color", color)
	return texto


func _construir() -> void:
	hud = MarginContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_theme_constant_override("margin_left", 28)
	hud.add_theme_constant_override("margin_top", 24)
	hud.add_theme_constant_override("margin_right", 28)
	hud.add_theme_constant_override("margin_bottom", 24)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(columna)
	columna.add_child(_texto("EL CORAZÓN DEL VOLCÁN", 14, Color(1, 0.7, 0.35)))
	objetivo = _texto("Recorre las plataformas y recupera el orbe.", 18, Color(0.95, 0.93, 0.88))
	columna.add_child(objetivo)
	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(espacio)
	ayuda_borde = _texto("Espacio: subir · S: soltarse", 23, Color(0.5, 0.95, 1))
	ayuda_borde.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda_borde.visible = false
	columna.add_child(ayuda_borde)
	columna.add_child(_texto("WASD / Flechas: mover   ·   Espacio: saltar   ·   E: interactuar   ·   V: cámara   ·   Esc: pausa", 14, Color(0.9, 0.87, 0.8)))
	fondo = ColorRect.new()
	fondo.color = Color(0.025, 0.018, 0.025, 0.82)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(530, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.075, 0.065, 0.08, 0.97)
	estilo.border_color = Color(0.8, 0.38, 0.16, 0.8)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(14)
	estilo.content_margin_left = 38
	estilo.content_margin_right = 38
	estilo.content_margin_top = 32
	estilo.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 18)
	panel.add_child(caja)
	var acento := _texto("P A R K O U R   V O L C Á N I C O", 14, Color(1, 0.66, 0.3))
	acento.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(acento)
	titulo = _texto("", 36, Color(1, 0.96, 0.88))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	descripcion = _texto("", 17, Color(0.78, 0.77, 0.79))
	descripcion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(descripcion)
	boton_principal = Button.new()
	boton_principal.custom_minimum_size = Vector2(0, 48)
	boton_principal.add_theme_font_size_override("font_size", 19)
	boton_principal.pressed.connect(_principal)
	caja.add_child(boton_principal)
	var salir := Button.new()
	salir.text = "Salir"
	salir.custom_minimum_size = Vector2(0, 42)
	salir.pressed.connect(func(): get_tree().quit())
	caja.add_child(salir)


func mostrar_menu(estado: String) -> void:
	menu_actual = estado
	fondo.show()
	hud.hide()
	match estado:
		"INICIO":
			titulo.text = "El corazón del volcán"
			descripcion.text = "Cruza la lava, recupera el orbe\ny devuélvelo al altar de origen.\n\nSi caes, tendrás que empezar de nuevo."
			boton_principal.text = "Jugar"
		"PAUSA":
			titulo.text = "Pausa"
			descripcion.text = "El volcán puede esperar."
			boton_principal.text = "Continuar"
		"DERROTA":
			titulo.text = "Has caído"
			descripcion.text = "El orbe ha vuelto a su pedestal.\nEl siguiente intento comienza desde el principio."
			boton_principal.text = "Reintentar"
		"VICTORIA":
			titulo.text = "Orbe colocado"
			descripcion.text = "Has recuperado el corazón del volcán.\nRecorrido completado."
			boton_principal.text = "Reiniciar escenario"
	boton_principal.grab_focus()


func cerrar_menu() -> void:
	fondo.hide()
	hud.show()
	boton_principal.release_focus()


func mostrar_objetivo(lugar: String) -> void:
	match lugar:
		"espalda":
			objetivo.text = "Orbe recuperado · Regresa al altar de origen."
		"transito":
			objetivo.text = "Colocando el orbe…"
		"destino":
			objetivo.text = "Orbe colocado · Recorrido completado."
		_:
			objetivo.text = "Recorre las plataformas y recupera el orbe."


func mostrar_agarre(activo: bool) -> void:
	ayuda_borde.visible = activo


func _principal() -> void:
	if menu_actual == "DERROTA" or menu_actual == "VICTORIA":
		reinicio_solicitado.emit()
	else:
		jugar_solicitado.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pausa_solicitada.emit()
		get_viewport().set_input_as_handled()
