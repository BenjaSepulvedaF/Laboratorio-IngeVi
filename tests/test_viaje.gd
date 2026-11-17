extends "res://tests/test_recorrido.gd"


# Viaje continuo desde la aparición hasta la entrega: sin teletransportes,
# sin cambiar velocidades, con colisiones y zonas de viento habilitadas.
func _ejecutar() -> void:
	seed(22062026)
	await cargar()
	await pasos(8)
	var apoyos := ruta_completa()
	for regreso in [false, true]:
		if regreso:
			# El pedestal ocupa el centro de la cima: se espera al orbe por el lado
			# de la bajada (como haría una persona) para no tener que rodearlo.
			var bajada: Vector3 = apoyos[apoyos.size() - 2].global_position - mundo.origen.global_position
			bajada.y = 0
			comprobar(await caminar_hasta(mundo.origen.global_position + bajada.normalized() * 1.35), "Aproximación al altar final")
			await pasos(5)
			await tecla(KEY_E)
			comprobar(jugador.objeto_llevado != "", "Recogida durante viaje continuo")
			apoyos.reverse()
		for i in range(apoyos.size() - 1):
			var nombre := "%s -> %s" % [apoyos[i].name, apoyos[i + 1].name]
			var exito := await saltar_entre(apoyos[i], apoyos[i + 1], false)
			comprobar(exito, "Viaje continuo " + nombre)
			if not exito:
				for q in get_nodes_in_group("inestables"): print("  ", q.name, " fase ", q.Fase.keys()[q.fase])
				print("VIAJE DETENIDO: ", nombre, " posición ", jugador.global_position, " estado ", jugador.estado)
				paused = false
				quit(1)
				return
			await pasos(3)
	# Vuelta al vestíbulo por el portal "Inicio", caminando.
	var portal: Vector3 = mundo.get_node("PuertaSpawn").global_position
	var volcan = mundo
	for frame in range(400):
		if not is_instance_valid(volcan) or current_scene != volcan:
			break
		var hacia: Vector3 = portal - jugador.global_position
		hacia.y = 0
		dirigir((hacia * 4.0).limit_length(jugador.SPEED))
		await pasos(1)
	soltar_controles()
	await pasos(10)
	comprobar(current_scene.scene_file_path == "res://niveles/spawn/spawn.tscn", "El portal Inicio lleva al vestíbulo")
	jugador = current_scene.jugador
	comprobar(jugador.orbe_id == "volcan", "El orbe llega al vestíbulo")
	# Hasta el pedestal del volcán en el monumento.
	var pedestal: Node3D = current_scene.monumento.pedestales["volcan"].nodo
	var junto: Vector3 = pedestal.global_position + (jugador.global_position - pedestal.global_position).normalized() * 1.2
	for frame in range(400):
		var hacia: Vector3 = junto - jugador.global_position
		hacia.y = 0
		if hacia.length() < 0.15:
			break
		dirigir((hacia * 4.0).limit_length(jugador.SPEED))
		await pasos(1)
	soltar_controles()
	await pasos(5)
	await tecla(KEY_E)
	await pasos(150)
	comprobar(progreso().entregado("volcan") and paused and current_scene.interfaz.menu_actual == "VICTORIA", "Victoria al colocar el orbe en el monumento")
	print("VIAJE COMPLETO: %d comprobaciones; %d fallos" % [comprobaciones, fallos])
	paused = false
	quit(1 if fallos else 0)
