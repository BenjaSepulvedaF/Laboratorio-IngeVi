extends "res://tests/test_partida.gd"

# Plataformas inestables (RigidBody3D): temblor al pisarlas, caída con la física
# del motor, reaparición, derrumbe estando colgado y controles con mando.


func poner_sobre(apoyo: PhysicsBody3D) -> void:
	var forma: BoxShape3D = apoyo.get_node("CollisionShape3D").shape
	jugador.desbloquear()
	jugador.global_position = apoyo.global_position + Vector3(0, forma.size.y * 0.5 + 1.03, 0)
	jugador.velocity = Vector3.ZERO


func segundos(s: float) -> void:
	await pasos(int(s * Engine.physics_ticks_per_second))


func _ejecutar() -> void:
	await cargar()
	# Sin viento: las ráfagas podrían sacar al jugador de la plataforma durante la prueba.
	for zona in ["ZonaViento1", "ZonaViento2", "ZonaViento3"]:
		mundo.get_node("Parkour/" + zona).aceleracion = 0.0
	var inestables := get_nodes_in_group("inestables")
	comprobar(inestables.size() == 3, "Hay tres plataformas inestables")
	for p in inestables:
		comprobar(p is RigidBody3D and p.freeze, p.name + " es un RigidBody3D congelado al inicio")

	var p = mundo.get_node("Parkour/Apoyo12")
	var origen: Vector3 = p.global_position
	poner_sobre(p)
	await segundos(0.3)
	comprobar(p.fase == p.Fase.TEMBLANDO and p.sonido.playing, "Pisarla la hace temblar con sonido")
	comprobar(not p.get_node("Roca").position.is_equal_approx(Vector3.ZERO), "La malla tiembla")
	comprobar(p.global_position.is_equal_approx(origen), "El colisionador no se mueve durante el temblor")
	poner_sobre(mundo.get_node("Parkour/Apoyo11"))
	await segundos(1.9)
	comprobar(p.fase == p.Fase.CAYENDO and not p.freeze, "Tras el aviso se descongela")
	comprobar(p.global_position.y < origen.y - 0.5 and p.angular_velocity.length() > 0.1, "Cae y gira por la física")
	comprobar(not p.is_in_group("agarrable") and p.collision_layer == 1, "Al caer deja de ser agarrable")
	await segundos(3.0)
	comprobar(p.fase == p.Fase.ESTABLE and p.global_position.is_equal_approx(origen) and p.freeze, "Reaparece en su sitio")
	comprobar(p.is_in_group("agarrable") and p.collision_layer == 3, "Al reaparecer vuelve a ser agarrable")

	for intento in range(3):
		await segundos(0.5)
		poner_sobre(p)
		await segundos(0.3)
		poner_sobre(mundo.get_node("Parkour/Apoyo11"))
		await segundos(5.0)
		comprobar(p.fase == p.Fase.ESTABLE and p.global_position.is_equal_approx(origen), "Ciclo repetible " + str(intento + 1))

	await colocar_junto_borde(p, Vector3.RIGHT)
	comprobar(jugador.estado == jugador.Estado.COLGADO and jugador.borde_agarrado == p, "Colgarse también activa la plataforma")
	await segundos(1.6)
	comprobar(jugador.estado != jugador.Estado.COLGADO, "El derrumbe suelta al jugador colgado")

	# Mando: cada acción responde a un botón o eje del gamepad.
	await cargar()
	await pasos(5)
	var y0: float = jugador.global_position.y
	await boton(JOY_BUTTON_A, true)
	await pasos(10)
	comprobar(jugador.global_position.y > y0 + 0.3, "Botón A: saltar")
	await boton(JOY_BUTTON_A, false)
	await pasos(80)
	var z0: float = jugador.global_position.z
	await eje(JOY_AXIS_LEFT_Y, -1.0)
	await pasos(30)
	comprobar(absf(jugador.global_position.z - z0) > 0.5, "Stick izquierdo: mover")
	await eje(JOY_AXIS_LEFT_Y, 0.0)
	var r0: float = jugador.rotation.y
	await eje(JOY_AXIS_RIGHT_X, 1.0)
	await pasos(30)
	comprobar(absf(jugador.rotation.y - r0) > 0.3, "Stick derecho: girar cámara")
	await eje(JOY_AXIS_RIGHT_X, 0.0)
	await boton(JOY_BUTTON_Y, true)
	await boton(JOY_BUTTON_Y, false)
	comprobar(jugador.first_person, "Botón Y: cambiar cámara")
	await boton(JOY_BUTTON_START, true)
	await boton(JOY_BUTTON_START, false)
	comprobar(paused and mundo.estado == mundo.Estado.PAUSA, "Start: pausa")
	print("INESTABLES: %d comprobaciones; %d fallos" % [comprobaciones, fallos])
	paused = false
	quit(1 if fallos else 0)


func boton(indice: JoyButton, presionado: bool) -> void:
	var evento := InputEventJoypadButton.new()
	evento.button_index = indice
	evento.pressed = presionado
	Input.parse_input_event(evento)
	await pasos(2)


func eje(indice: JoyAxis, valor: float) -> void:
	var evento := InputEventJoypadMotion.new()
	evento.axis = indice
	evento.axis_value = valor
	Input.parse_input_event(evento)
	await pasos(1)
