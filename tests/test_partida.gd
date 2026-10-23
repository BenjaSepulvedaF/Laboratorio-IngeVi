extends SceneTree

var fallos := 0
var comprobaciones := 0
var mundo
var jugador


func _initialize() -> void:
	call_deferred("_ejecutar")


func comprobar(condicion: bool, mensaje: String) -> void:
	comprobaciones += 1
	if not condicion:
		fallos += 1
		push_error("PRUEBA: " + mensaje)


func pasos(cantidad: int) -> void:
	for i in range(cantidad):
		await physics_frame
		await process_frame


func tecla(codigo: Key) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.pressed = true
	Input.parse_input_event(evento)
	await pasos(1)
	evento = InputEventKey.new()
	evento.keycode = codigo
	evento.pressed = false
	Input.parse_input_event(evento)
	await pasos(1)


func cargar(inicio_directo: bool = true) -> void:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.free()
	if inicio_directo:
		set_meta("volcan_inicio_directo", true)
	mundo = load("res://mundo.tscn").instantiate()
	root.add_child(mundo)
	current_scene = mundo
	jugador = mundo.jugador
	await pasos(3)


func recoger() -> void:
	jugador.global_position = mundo.origen.global_position + Vector3(0, 1.025, 1.5)
	jugador.velocity = Vector3.ZERO
	await pasos(5)
	await tecla(KEY_E)
	comprobar(jugador.objeto_llevado == "Orbe Sagrado", "E recoge el orbe en proximidad")
	comprobar(not mundo.origen.orbe.visible and jugador.visual.orbe_espalda.visible, "El orbe pasa del pedestal a la espalda")


func colocar_junto_borde(apoyo: StaticBody3D, direccion: Vector3) -> void:
	var forma: BoxShape3D = apoyo.get_node("CollisionShape3D").shape
	var alto: float = apoyo.get_meta("altura_superficie")
	var borde := Vector3(direccion.x * (forma.size.x * 0.5 + 0.42), 0, direccion.z * (forma.size.z * 0.5 + 0.42))
	jugador.desbloquear()
	jugador.bloqueo_agarre = 0.0
	jugador.global_position = apoyo.global_position + borde
	jugador.global_position.y = alto - 0.8
	jugador.velocity = Vector3(0, -0.2, 0)
	await pasos(3)


func _ejecutar() -> void:
	await cargar(false)
	comprobar(paused and mundo.estado == mundo.Estado.INICIO, "El inicio pausa el mundo")
	comprobar(mundo.interfaz.boton_principal.text == "Jugar", "Menú inicial")
	mundo.interfaz.boton_principal.pressed.emit()
	await pasos(20)
	comprobar(jugador.is_on_floor() and jugador.position.y > 3.9, "La isla inicial es segura")
	comprobar(get_nodes_in_group("apoyos").size() == 24, "Hay 24 apoyos")
	var posicion: Vector3 = jugador.position
	await tecla(KEY_ESCAPE)
	await pasos(10)
	comprobar(paused and jugador.position.is_equal_approx(posicion), "Esc pausa sin mover al personaje")
	await tecla(KEY_ESCAPE)
	comprobar(not paused, "Esc reanuda")

	await recoger()
	var altura_orbe: float = jugador.visual.orbe_espalda.get_node("Visual").position.y
	await pasos(10)
	comprobar(not is_equal_approx(altura_orbe, jugador.visual.orbe_espalda.get_node("Visual").position.y), "El orbe flota")
	await tecla(KEY_V)
	comprobar(jugador.first_person and not jugador.visual.is_visible_in_tree(), "Primera persona oculta cuerpo y orbe")
	await tecla(KEY_V)
	comprobar(not jugador.first_person and jugador.visual.orbe_espalda.is_visible_in_tree(), "Tercera persona muestra el orbe")
	jugador.global_position = Vector3(15, 1.3, 0)
	jugador.velocity = Vector3(0, -4, 0)
	await pasos(35)
	comprobar(mundo.estado == mundo.Estado.DERROTA and paused, "La lava muestra derrota")
	comprobar(jugador.objeto_llevado == "" and mundo.origen.orbe.visible, "Morir devuelve el orbe al origen")
	comprobar(not jugador.visual.orbe_espalda.visible and not mundo.destino.orbe.visible, "No hay copias del orbe tras morir")

	for intento in range(3):
		mundo.interfaz.boton_principal.pressed.emit()
		await pasos(5)
		mundo = current_scene
		jugador = mundo.jugador
		comprobar(mundo.estado == mundo.Estado.JUGANDO and not paused, "Reintento directo " + str(intento))
		comprobar(jugador.position.distance_to(Vector3(0, 4, 1)) < 0.1 and mundo.origen.tiene_objeto, "Reinicio completo " + str(intento))
		if intento < 2:
			jugador.global_position = Vector3(15, -9, 0)
			await pasos(3)
			comprobar(mundo.estado == mundo.Estado.DERROTA, "Límite inferior letal")

	var apoyo = mundo.get_node("Parkour/Apoyo01")
	for direccion in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		await colocar_junto_borde(apoyo, direccion)
		comprobar(jugador.estado == jugador.Estado.COLGADO, "Agarre automático en cara " + str(direccion))
		if jugador.estado != jugador.Estado.COLGADO:
			continue
		comprobar(mundo.interfaz.ayuda_borde.visible, "Ayuda de borde visible")
		var colgado: Vector3 = jugador.position
		jugador.aplicar_viento(Vector3(20, 0, 0), 1)
		await pasos(15)
		comprobar(jugador.position.is_equal_approx(colgado) and jugador.viento_restante == 0, "Colgado no acumula viento")
		await tecla(KEY_ESCAPE)
		await pasos(5)
		comprobar(jugador.position.is_equal_approx(colgado), "Pausa colgado")
		await tecla(KEY_ESCAPE)
		Input.action_press("ui_accept")
		await pasos(5)
		Input.action_release("ui_accept")
		comprobar(jugador.estado == jugador.Estado.ESCALANDO, "Espacio inicia escalada")
		await tecla(KEY_ESCAPE)
		posicion = jugador.position
		await pasos(10)
		comprobar(jugador.position.is_equal_approx(posicion), "Pausa durante escalada")
		await tecla(KEY_ESCAPE)
		await pasos(45)
		comprobar(jugador.estado == jugador.Estado.NORMAL and jugador.is_on_floor(), "Escalada termina sobre la plataforma")

	await colocar_junto_borde(apoyo, Vector3.RIGHT)
	Input.action_press("ui_down")
	await pasos(2)
	Input.action_release("ui_down")
	comprobar(jugador.estado == jugador.Estado.NORMAL and jugador.bloqueo_agarre > 0.3, "S suelta con bloqueo de reagarre")
	await pasos(5)
	comprobar(jugador.estado == jugador.Estado.NORMAL, "No hay reagarre inmediato")

	await colocar_junto_borde(apoyo, Vector3.RIGHT)
	var obstaculo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1, 1, 1)
	forma.shape = caja
	obstaculo.add_child(forma)
	mundo.add_child(obstaculo)
	obstaculo.global_position = jugador.punto_destino + Vector3.UP * 0.4
	await pasos(2)
	await colocar_junto_borde(apoyo, Vector3.RIGHT)
	comprobar(jugador.estado == jugador.Estado.COLGADO, "Un techo permite colgarse aunque impida subir")
	Input.action_press("ui_accept")
	await pasos(3)
	Input.action_release("ui_accept")
	comprobar(jugador.estado == jugador.Estado.COLGADO, "Destino bloqueado impide subir")
	obstaculo.queue_free()
	await pasos(2)

	await cargar()
	await recoger()
	apoyo = mundo.get_node("Parkour/Apoyo11")
	await colocar_junto_borde(apoyo, Vector3.RIGHT)
	comprobar(jugador.estado == jugador.Estado.COLGADO, "Agarre de viga con orbe")
	Input.action_press("ui_accept")
	await pasos(45)
	Input.action_release("ui_accept")
	comprobar(jugador.is_on_floor() and jugador.objeto_llevado != "", "Subir conserva el orbe")

	jugador.global_position = mundo.destino.global_position + Vector3(0, 1.025, -1.5)
	jugador.velocity = Vector3.ZERO
	await pasos(5)
	await tecla(KEY_E)
	comprobar(mundo.estado == mundo.Estado.ENTREGA, "E inicia la entrega")
	comprobar(mundo.interfaz.objetivo.text == "Colocando el orbe…", "Objetivo durante la animación de entrega")
	comprobar(mundo.orbe_transito.visible and not jugador.visual.orbe_espalda.visible and not mundo.destino.orbe.visible, "Un solo orbe durante la entrega")
	await tecla(KEY_E)
	await pasos(10)
	await tecla(KEY_ESCAPE)
	posicion = mundo.orbe_transito.position
	await pasos(20)
	comprobar(mundo.orbe_transito.position.is_equal_approx(posicion), "Pausa congela entrega")
	await tecla(KEY_ESCAPE)
	await pasos(100)
	comprobar(mundo.estado == mundo.Estado.VICTORIA and paused, "Entrega termina en victoria")
	comprobar(mundo.destino.completado and mundo.destino.orbe.visible and not mundo.origen.orbe.visible, "Orbe colocado sin duplicación")
	comprobar(mundo.interfaz.titulo.text == "Orbe colocado" and mundo.interfaz.boton_principal.text == "Reiniciar escenario", "Texto y botón de victoria")
	mundo.interfaz.boton_principal.pressed.emit()
	await pasos(5)
	mundo = current_scene
	jugador = mundo.jugador
	comprobar(mundo.estado == mundo.Estado.JUGANDO and mundo.origen.orbe.visible and not mundo.destino.completado, "Reinicio desde victoria")

	print("RESULTADO: %d comprobaciones; %d fallos" % [comprobaciones, fallos])
	paused = false
	quit(1 if fallos else 0)
