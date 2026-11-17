extends CanvasLayer

signal jugar_solicitado
signal reinicio_solicitado
signal pausa_solicitada
signal vestibulo_solicitado
signal titulo_terminado

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
var cronometro: Label
var tarjeta_titulo: Control
var panel_agarre: PanelContainer
var tween_titulo: Tween
var tarjeta_capitulo: Label
var tarjeta_nombre: Label
var tarjeta_texto: Label
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


# Texto del HUD: con contorno oscuro para leerse sobre cualquier fondo
# (el cielo claro del vestíbulo o la lava brillante del volcán).
func _texto_hud(contenido: String, tamano: int, color: Color) -> Label:
	var texto := _texto(contenido, tamano, color)
	texto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	texto.add_theme_constant_override("outline_size", 5)
	return texto


# Panel del HUD: fondo oscuro semitransparente con borde fino, el mismo estilo de
# los menús. Da contraste igual en todos los escenarios sin ajustar nada por nivel.
func _panel_hud(alineacion: Control.SizeFlags) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = alineacion
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.045, 0.03, 0.035, 0.74)
	estilo.border_color = Color(1, 0.55, 0.2, 0.45)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 16
	estilo.content_margin_right = 16
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", estilo)
	return panel


func _construir() -> void:
	hud = MarginContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_theme_constant_override("margin_left", 24)
	hud.add_theme_constant_override("margin_top", 20)
	hud.add_theme_constant_override("margin_right", 24)
	hud.add_theme_constant_override("margin_bottom", 20)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(columna)
	# Panel de estado (arriba a la izquierda): objetivo, calor, cristales y tiempo.
	var panel_estado := _panel_hud(Control.SIZE_SHRINK_BEGIN)
	columna.add_child(panel_estado)
	var estado := VBoxContainer.new()
	estado.add_theme_constant_override("separation", 6)
	estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_estado.add_child(estado)
	estado.add_child(_texto_hud("EL CORAZÓN DEL VOLCÁN", 13, Color(1, 0.7, 0.35)))
	objetivo = _texto_hud("Recorre las plataformas y recupera el orbe.", 18, Color(1, 0.97, 0.92))
	estado.add_child(objetivo)
	barra_salud = BarraSalud.new()
	estado.add_child(barra_salud)
	contador_cristales = _texto_hud("", 16, Color(0.55, 0.92, 1.0))
	contador_cristales.visible = false
	estado.add_child(contador_cristales)
	# Cronómetro del intento: lo lleva Progreso y avisa una vez por segundo.
	cronometro = _texto_hud("", 16, Color(1, 0.97, 0.92))
	estado.add_child(cronometro)
	_on_cronometro_cambiado(Progreso.cronometro_activo)
	_on_tiempo_cambiado(int(Progreso.tiempo))
	Progreso.tiempo_cambiado.connect(_on_tiempo_cambiado)
	Progreso.cronometro_cambiado.connect(_on_cronometro_cambiado)
	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(espacio)
	# Ayuda al colgarse (centro): solo aparece cuando hace falta.
	panel_agarre = _panel_hud(Control.SIZE_SHRINK_CENTER)
	panel_agarre.visible = false
	columna.add_child(panel_agarre)
	ayuda_borde = _texto_hud("", 22, Color(0.55, 0.95, 1))
	ayuda_borde.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda_borde.visible = false
	panel_agarre.add_child(ayuda_borde)
	# Controles (abajo, centrados).
	var panel_controles := _panel_hud(Control.SIZE_SHRINK_CENTER)
	columna.add_child(panel_controles)
	ayuda_controles = _texto_hud("", 14, Color(0.95, 0.92, 0.86))
	panel_controles.add_child(ayuda_controles)
	_actualizar_ayudas()
	Dispositivo.cambiado.connect(func(_mando): _actualizar_ayudas())
	_construir_tarjeta_titulo()
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


func _on_tiempo_cambiado(segundos: int) -> void:
	cronometro.text = "Tiempo  " + Progreso.formato(segundos)


func _on_cronometro_cambiado(activo: bool) -> void:
	cronometro.visible = activo


# Título del nivel (elemento narrativo): aparece al entrar, se sostiene y se
# desvanece. No bloquea el juego; avisa con titulo_terminado al desaparecer.
func _construir_tarjeta_titulo() -> void:
	tarjeta_titulo = CenterContainer.new()
	tarjeta_titulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tarjeta_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta_titulo.visible = false
	add_child(tarjeta_titulo)
	# Panel detrás del título, con el mismo estilo del HUD pero más amplio.
	var fondo_titulo := _panel_hud(Control.SIZE_SHRINK_CENTER)
	var estilo_titulo := fondo_titulo.get_theme_stylebox("panel") as StyleBoxFlat
	estilo_titulo.bg_color.a = 0.62
	estilo_titulo.content_margin_left = 48
	estilo_titulo.content_margin_right = 48
	estilo_titulo.content_margin_top = 26
	estilo_titulo.content_margin_bottom = 28
	tarjeta_titulo.add_child(fondo_titulo)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo_titulo.add_child(caja)
	tarjeta_capitulo = _texto("", 18, Color(1, 0.66, 0.3))
	tarjeta_nombre = _texto("", 52, Color(1, 0.96, 0.88))
	tarjeta_texto = _texto("", 19, Color(0.9, 0.86, 0.82))
	for etiqueta in [tarjeta_capitulo, tarjeta_nombre, tarjeta_texto]:
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		etiqueta.add_theme_constant_override("outline_size", 10)
		caja.add_child(etiqueta)


func mostrar_titulo(capitulo: String, nombre: String, texto: String) -> void:
	tarjeta_capitulo.text = capitulo
	tarjeta_nombre.text = nombre
	tarjeta_texto.text = texto
	tarjeta_titulo.visible = true
	tarjeta_titulo.modulate.a = 0.0
	tween_titulo = create_tween()
	# STOP: si se pausa el juego durante el título, el título también se detiene.
	tween_titulo.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween_titulo.tween_property(tarjeta_titulo, "modulate:a", 1.0, 0.7)
	tween_titulo.tween_interval(4.5) # tiempo para leer las dos líneas con calma
	_terminar_titulo(0.9)


# Desvanece el título y avisa. Se usa al final normal y al saltarlo.
func _terminar_titulo(duracion: float) -> void:
	tween_titulo.tween_property(tarjeta_titulo, "modulate:a", 0.0, duracion)
	tween_titulo.tween_callback(func():
		tarjeta_titulo.visible = false
		titulo_terminado.emit())


# Saltar el título (con Saltar o Interactuar): útil al volver a entrar al nivel.
func saltar_titulo() -> void:
	if not tarjeta_titulo.visible or get_tree().paused:
		return
	tween_titulo.kill()
	tween_titulo = create_tween()
	tween_titulo.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_terminar_titulo(0.3)


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
			descripcion.text = "El monumento vuelve a arder:\nhas recuperado el corazón del volcán.\n\nTiempo: %s   ·   Mejor: %s" % [
				Progreso.formato(Progreso.tiempo_final), Progreso.formato(Progreso.mejor_tiempo)]
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
	panel_agarre.visible = activo


func _principal() -> void:
	# Suelto: "Reintentar" y "Reiniciar escenario" recargan la escena y lo cortarían.
	SonidoSuelto.reproducir(get_tree(), SONIDO_CLICK)
	if menu_actual == "DERROTA" or menu_actual == "VICTORIA":
		reinicio_solicitado.emit()
	else:
		jugar_solicitado.emit()


func _unhandled_input(event: InputEvent) -> void:
	if tarjeta_titulo.visible and (event.is_action_pressed("saltar") or event.is_action_pressed("interactuar")):
		saltar_titulo()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pausa"):
		pausa_solicitada.emit()
		get_viewport().set_input_as_handled()
