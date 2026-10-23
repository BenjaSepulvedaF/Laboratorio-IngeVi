extends "res://tests/test_partida.gd"


func soltar_controles() -> void:
	for accion in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		Input.action_release(accion)


func dirigir(velocidad_deseada: Vector3) -> void:
	var local: Vector3 = (jugador.global_basis.inverse() * (velocidad_deseada - jugador.velocidad_viento) / jugador.SPEED).limit_length(1.0)
	if local.length() > 0.01:
		local = local.normalized() * (0.5 + local.length() * 0.5)
	for accion in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		Input.action_release(accion)
	if local.z < 0:
		Input.action_press("ui_up", -local.z)
	else:
		Input.action_press("ui_down", local.z)
	if local.x < 0:
		Input.action_press("ui_left", -local.x)
	else:
		Input.action_press("ui_right", local.x)


func caminar_hasta(objetivo: Vector3) -> bool:
	for frame in range(140):
		var restante: Vector3 = objetivo - jugador.global_position
		restante.y = 0
		if restante.length() < 0.09:
			soltar_controles()
			return true
		dirigir((restante * 4.0).limit_length(jugador.SPEED))
		await pasos(1)
		if mundo.estado == mundo.Estado.DERROTA or jugador.estado != jugador.Estado.NORMAL:
			return false
	return false


func saltar_entre(desde: StaticBody3D, hasta: StaticBody3D, preparar: bool = true) -> bool:
	soltar_controles()
	var forma: BoxShape3D = desde.get_node("CollisionShape3D").shape
	var objetivo_forma: BoxShape3D = hasta.get_node("CollisionShape3D").shape
	var centro_destino: Vector3 = hasta.global_position
	if hasta.name == "Apoyo24":
		centro_destino.x += 1.3 # El pedestal ocupa el centro de este apoyo.
	var direccion: Vector3 = centro_destino - desde.global_position
	direccion.y = 0
	direccion = direccion.normalized()
	var distancia_borde := minf((forma.size.x * 0.5 - 0.2) / maxf(absf(direccion.x), 0.001), (forma.size.z * 0.5 - 0.2) / maxf(absf(direccion.z), 0.001))
	if preparar:
		jugador.desbloquear()
		jugador.bloqueo_agarre = 0.0
		jugador.global_position = desde.global_position + direccion * distancia_borde
		jugador.position.y = desde.global_position.y + forma.size.y * 0.5 + 1.025
		jugador.velocity = Vector3.ZERO
		jugador.look_at(jugador.global_position + direccion)
		await pasos(4)
		jugador.velocity = direccion * jugador.SPEED
		Input.action_press("ui_up")
	else:
		var lanzamiento: Vector3 = desde.global_position + direccion * distancia_borde
		if not await caminar_hasta(lanzamiento - direccion * 0.8):
			return false
		for frame in range(30):
			var restante: Vector3 = lanzamiento - jugador.global_position
			restante.y = 0
			if restante.dot(direccion) < 0.08:
				break
			dirigir(direccion * jugador.SPEED)
			await pasos(1)
	Input.action_press("ui_accept")
	var estuvo_en_aire := false
	var termino := false
	for frame in range(110):
		await pasos(1)
		var restante: Vector3 = centro_destino - jugador.global_position
		restante.y = 0.0
		# Guiar con las mismas acciones analógicas que usa un mando, compensando
		# el viento. Cada salto usa física real, sin recolocar al jugador en vuelo.
		dirigir((restante * 4.0).limit_length(jugador.SPEED))
		if mundo.estado == mundo.Estado.DERROTA:
			break
		if jugador.estado == jugador.Estado.COLGADO:
			Input.action_release("ui_up")
			Input.action_release("ui_accept")
			await pasos(1)
			Input.action_press("ui_accept")
			await pasos(45)
			termino = jugador.is_on_floor()
			break
		if not jugador.is_on_floor():
			estuvo_en_aire = true
		if estuvo_en_aire and jugador.is_on_floor():
			termino = true
			break
	soltar_controles()
	var diferencia: Vector3 = jugador.global_position - hasta.global_position
	var sobre_destino := absf(diferencia.x) < objetivo_forma.size.x * 0.5 + 0.15 and absf(diferencia.z) < objetivo_forma.size.z * 0.5 + 0.15
	var altura_correcta := absf(diferencia.y - objetivo_forma.size.y * 0.5 - 1.0) < 0.12
	if not (termino and sobre_destino and altura_correcta):
		print("SALTO FALLIDO %s -> %s; posición %s; estado %s" % [desde.name, hasta.name, jugador.global_position, jugador.estado])
	return termino and sobre_destino and altura_correcta


func _ejecutar() -> void:
	await cargar()
	var apoyos: Array[StaticBody3D] = [mundo.get_node("IslaInicial")]
	for i in range(1, 25):
		apoyos.append(mundo.get_node("Parkour/Apoyo%02d" % i))
	for regreso in [false, true]:
		if regreso:
			apoyos.reverse()
		for i in range(apoyos.size() - 1):
			if paused:
				await cargar()
				# La recarga reemplaza las referencias de los cuerpos del circuito.
				for j in range(apoyos.size()):
					var indice := 24 - j if regreso else j
					apoyos[j] = mundo.get_node("IslaInicial") if indice == 0 else mundo.get_node("Parkour/Apoyo%02d" % indice)
			var nombre := "%s -> %s" % [apoyos[i].name, apoyos[i + 1].name]
			comprobar(await saltar_entre(apoyos[i], apoyos[i + 1]), "Salto " + nombre)
	print("RECORRIDO: %d saltos de ida/vuelta; %d fallos" % [comprobaciones, fallos])
	paused = false
	quit(1 if fallos else 0)
