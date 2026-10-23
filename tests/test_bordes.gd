extends "res://tests/test_partida.gd"


func _ejecutar() -> void:
	await cargar()
	await recoger()
	for i in range(1, 25):
		var apoyo = mundo.get_node("Parkour/Apoyo%02d" % i)
		for direccion in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			await colocar_junto_borde(apoyo, direccion)
			comprobar(jugador.estado == jugador.Estado.COLGADO, "Cara agarrable de " + apoyo.name + " " + str(direccion))
			comprobar(jugador.objeto_llevado != "" and jugador.visual.orbe_espalda.visible, "Colgarse conserva el orbe")
			if jugador.estado != jugador.Estado.COLGADO:
				continue
			Input.action_press("ui_accept")
			await pasos(42)
			Input.action_release("ui_accept")
			comprobar(jugador.estado == jugador.Estado.NORMAL and jugador.is_on_floor(), "Escalada en " + apoyo.name + " " + str(direccion))

	var apoyo = mundo.get_node("Parkour/Apoyo01")
	await colocar_junto_borde(apoyo, Vector3.RIGHT)
	await tecla(KEY_V)
	comprobar(jugador.first_person and not jugador.visual.is_visible_in_tree(), "Cámara en primera persona al colgarse")
	await pasos(650)
	comprobar(jugador.estado == jugador.Estado.COLGADO, "El agarre no tiene límite de tiempo")
	Input.action_press("ui_accept")
	await pasos(42)
	Input.action_release("ui_accept")
	comprobar(jugador.is_on_floor() and jugador.first_person, "Escalada en primera persona")
	await tecla(KEY_V)

	for diagonal in [Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
		jugador.desbloquear()
		jugador.bloqueo_agarre = 0
		jugador.global_position = apoyo.global_position + diagonal * 1.8
		jugador.global_position.y = 2.2
		jugador.velocity = Vector3(0, -0.2, 0)
		await pasos(3)
		comprobar(jugador.estado == jugador.Estado.COLGADO, "Agarre en esquina " + str(diagonal))
		if jugador.estado == jugador.Estado.COLGADO:
			comprobar(jugador._espacio_libre(jugador.global_position), "La esquina no incrusta la cápsula")

	jugador.desbloquear()
	jugador.bloqueo_agarre = 0
	jugador.global_position = Vector3(2.8, 2.2, -7)
	jugador.velocity = Vector3(0, -0.2, 0)
	await pasos(3)
	comprobar(jugador.estado == jugador.Estado.NORMAL, "Un borde lejano no atrae al jugador")

	# Un pedestal no pertenece a la máscara/grupo de superficies agarrables.
	jugador.global_position = mundo.destino.global_position + Vector3(1, 0.1, 0)
	jugador.velocity = Vector3(0, -0.2, 0)
	await pasos(3)
	comprobar(jugador.estado == jugador.Estado.NORMAL, "El pedestal no es agarrable")
	jugador.global_position = Vector3(300, -9, 300)
	await pasos(3)
	comprobar(mundo.estado == mundo.Estado.DERROTA, "Fuera del área de lava funciona el límite inferior")
	await tecla(KEY_ESCAPE)
	comprobar(paused and mundo.estado == mundo.Estado.DERROTA, "Esc no reanuda una derrota")
	print("BORDES: %d comprobaciones; %d fallos" % [comprobaciones, fallos])
	paused = false
	quit(1 if fallos else 0)
