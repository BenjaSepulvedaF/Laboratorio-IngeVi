extends CanvasLayer

signal jugar_solicitado
signal reinicio_solicitado
signal pausa_solicitada
signal vestibulo_solicitado

const SONIDO_CLICK = preload("res://assets/audio/click_menu.wav")
const SONIDO_PAUSA = preload("res://assets/audio/pausa.wav")
const SONIDO_VICTORIA = preload("res://assets/audio/victoria.wav")

var fondo: ColorRect
var titulo: Label
var descripcion: Label
var boton_principal: Button
var objetivo: Label
var ayuda_borde: Label
var ayuda_controles: Label
var hud: MarginContainer
var menu_actual := "INICIO"
var barra_salud: BarraSalud
var contador_cristales: Label
var tween_cristales: Tween
var boton_vestibulo: Button
var tween_fondo: Tween
# La fija partida.gd antes de mostrar la derrota: "calor", "lava" o "caida".
var causa_derrota := ""
# Solo los niveles ofrecen volver al vestíbulo (en el vestíbulo no tiene sentido).
var permite_vestibulo := false
var sonido_pausa: AudioStreamPlayer
var sonido_victoria: AudioStreamPlayer


func _ready() -> void:
	# Always: la interfaz (y sus sonidos) funciona con el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_construir()
	sonido_pausa = _reproductor(SONIDO_PAUSA)
	sonido_victoria = _reproductor(SONIDO_VICTORIA)


func _reproductor(sonido: AudioStream) -> AudioStreamPlayer:
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = sonido
	reproductor.volume_db = -3.0
	reproductor.bus = &"SFX"
	add_child(reproductor)
	return reproductor


func reproducir_pausa() -> void:
	sonido_pausa.play()


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
	barra_salud = BarraSalud.new()
	columna.add_child(barra_salud)
	contador_cristales = _texto("", 16, Color(0.55, 0.9, 1.0))
	contador_cristales.visible = false
	columna.add_child(contador_cristales)
	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(espacio)
	ayuda_borde = _texto("", 23, Color(0.5, 0.95, 1))
	ayuda_borde.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda_borde.visible = false
	columna.add_child(ayuda_borde)
	ayuda_controles = _texto("", 14, Color(0.9, 0.87, 0.8))
	columna.add_child(ayuda_controles)
	_actualizar_ayudas()
	Dispositivo.cambiado.connect(func(_mando): _actualizar_ayudas())
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
	boton_vestibulo = Button.new()
	boton_vestibulo.text = "Volver al vestíbulo"
	boton_vestibulo.custom_minimum_size = Vector2(0, 42)
	boton_vestibulo.pressed.connect(func():
		SonidoSuelto.reproducir(get_tree(), SONIDO_CLICK)
		vestibulo_solicitado.emit())
	caja.add_child(boton_vestibulo)
	var salir := Button.new()
	salir.text = "Salir"
	salir.custom_minimum_size = Vector2(0, 42)
	salir.pressed.connect(func(): get_tree().quit())
	caja.add_child(salir)


# Los textos de ayuda muestran solo los botones del dispositivo en uso.
func _actualizar_ayudas() -> void:
	ayuda_borde.text = Dispositivo.texto("Espacio: subir · S: soltarse", "Botón A: subir · Abajo: soltarse")
	ayuda_controles.text = Dispositivo.texto(
		"WASD / Flechas: mover   ·   Espacio: saltar   ·   Shift: agacharse   ·   E: interactuar   ·   V: cámara   ·   Esc: pausa",
		"Stick izq.: mover   ·   Stick der.: cámara   ·   A: saltar   ·   B: agacharse   ·   X: interactuar   ·   Y: vista   ·   Start: pausa")


# La llama partida.gd cada vez que se recoge un cristal (no se consulta por frame).
func mostrar_cristales(recogidos: int, total: int) -> void:
	contador_cristales.visible = total > 0
	contador_cristales.text = "◆ Cristales de agua: %d / %d" % [recogidos, total]
	if recogidos == 0:
		return
	# Feedback: el contador crece y brilla un instante al sumar uno.
	if tween_cristales:
		tween_cristales.kill()
	contador_cristales.pivot_offset = contador_cristales.size * Vector2(0.0, 0.5)
	contador_cristales.scale = Vector2.ONE * 1.35
	contador_cristales.modulate = Color(1.6, 1.6, 1.6)
	tween_cristales = create_tween().set_parallel()
	tween_cristales.tween_property(contador_cristales, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	tween_cristales.tween_property(contador_cristales, "modulate", Color.WHITE, 0.4)


func conectar_salud(salud: Salud) -> void:
	barra_salud.conectar(salud)


func mostrar_menu(estado: String) -> void:
	menu_actual = estado
	fondo.show()
	hud.hide()
	boton_vestibulo.visible = permite_vestibulo and estado != "INICIO"
	# Aparición con fundido: el paso del juego al menú no es un corte seco.
	if tween_fondo:
		tween_fondo.kill()
	fondo.modulate.a = 0.0
	tween_fondo = create_tween()
	tween_fondo.tween_property(fondo, "modulate:a", 1.0, 0.35)
	match estado:
		"INICIO":
			titulo.text = "El corazón del volcán"
			descripcion.text = "Cruza la lava, recupera el orbe\ny llévalo al monumento del vestíbulo.\n\nEl calor consume tu resistencia: no te detengas.\nSi caes o te quemas, empiezas de nuevo."
			boton_principal.text = "Jugar"
		"PAUSA":
			titulo.text = "Pausa"
			descripcion.text = "El volcán puede esperar."
			boton_principal.text = "Continuar"
		"DERROTA":
			if causa_derrota == "calor":
				titulo.text = "El calor te venció"
				descripcion.text = "Tu resistencia se agotó.\nEl orbe ha vuelto a su pedestal."
			else:
				titulo.text = "Has caído"
				descripcion.text = "El orbe ha vuelto a su pedestal.\nEl siguiente intento comienza desde el principio."
			boton_principal.text = "Reintentar"
		"VICTORIA":
			titulo.text = "Orbe colocado"
			descripcion.text = "El monumento vuelve a arder:\nhas recuperado el corazón del volcán."
			boton_principal.text = "Jugar de nuevo"
			sonido_victoria.play()
	boton_principal.grab_focus()


func cerrar_menu() -> void:
	fondo.hide()
	hud.show()
	boton_principal.release_focus()


func mostrar_objetivo(lugar: String) -> void:
	match lugar:
		"espalda":
			objetivo.text = "Orbe recuperado · Vuelve al portal Inicio y llévalo al monumento."
		"monumento":
			objetivo.text = "Coloca el orbe en su pedestal del monumento."
		"portal_abierto":
			objetivo.text = "Orbe colocado · Se abrió un nuevo portal."
		"entregado":
			objetivo.text = "Ya colocaste este orbe en el monumento."
		"vestibulo":
			objetivo.text = "Cruza el portal Parkour para entrar al volcán."
		_:
			objetivo.text = "Recorre las plataformas y recupera el orbe."


func mostrar_agarre(activo: bool) -> void:
	ayuda_borde.visible = activo


func _principal() -> void:
	# Suelto: "Reintentar" y "Reiniciar escenario" recargan la escena y lo cortarían.
	SonidoSuelto.reproducir(get_tree(), SONIDO_CLICK)
	if menu_actual == "DERROTA" or menu_actual == "VICTORIA":
		reinicio_solicitado.emit()
	else:
		jugar_solicitado.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pausa"):
		pausa_solicitada.emit()
		get_viewport().set_input_as_handled()
