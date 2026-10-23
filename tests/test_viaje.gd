extends "res://tests/test_recorrido.gd"


# Viaje continuo desde la aparición hasta la entrega: sin teletransportes,
# sin cambiar velocidades, con colisiones y zonas de viento habilitadas.
func _ejecutar() -> void:
	seed(22062026)
	await cargar()
	await pasos(8)
	var apoyos: Array[StaticBody3D] = [mundo.get_node("IslaInicial")]
	for i in range(1, 25):
		apoyos.append(mundo.get_node("Parkour/Apoyo%02d" % i))
	for regreso in [false, true]:
		if regreso:
			comprobar(await caminar_hasta(mundo.origen.global_position + Vector3(1.35, 0, 0.7)), "Aproximación al altar final")
			await pasos(5)
			await tecla(KEY_E)
			comprobar(jugador.objeto_llevado != "", "Recogida durante viaje continuo")
			apoyos.reverse()
		for i in range(apoyos.size() - 1):
			var nombre := "%s -> %s" % [apoyos[i].name, apoyos[i + 1].name]
			var exito := await saltar_entre(apoyos[i], apoyos[i + 1], false)
			comprobar(exito, "Viaje continuo " + nombre)
			if not exito:
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
