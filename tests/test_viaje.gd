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
	comprobar(await caminar_hasta(mundo.destino.global_position + Vector3(1.35, 0, -0.6)), "Regreso al altar inicial")
	await pasos(5)
	await tecla(KEY_E)
	await pasos(100)
	comprobar(mundo.estado == mundo.Estado.VICTORIA, "Victoria tras el viaje completo")
	print("VIAJE COMPLETO: %d comprobaciones; %d fallos" % [comprobaciones, fallos])
	paused = false
	quit(1 if fallos else 0)
