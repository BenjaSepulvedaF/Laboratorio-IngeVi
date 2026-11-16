extends "res://tests/test_recorrido.gd"

# Desvíos y cristales de agua: en varios mapas, cada desvío se recorre saltando
# (ida y vuelta, también el que termina en plataforma inestable), su cristal
# recupera salud una sola vez y el HUD lo cuenta. Además, agachado quema x1.5.


func _ejecutar() -> void:
	calor_activo = false
	for semilla in [3, 17, 42, 99, 123]:
		await cargar(true, semilla)
		var generador = mundo.get_node("Parkour")
		comprobar(generador.rutas_desvios.size() == 3, "Mapa %d: tres desvíos" % semilla)
		for numero in generador.rutas_desvios.size():
			var ruta: Array = generador.rutas_desvios[numero]
			var etiqueta := "mapa %d, desvío %d" % [semilla, numero + 1]
			jugador.salud.danar(50.0)
			var antes: float = jugador.salud.actual
			var ok := true
			for k in ruta.size() - 1:
				ok = ok and await saltar_entre(ruta[k], ruta[k + 1])
			comprobar(ok, "Ida por el " + etiqueta)
			await pasos(5)
			comprobar(jugador.salud.actual > antes + 30.0, "El cristal del %s recupera salud" % etiqueta)
			comprobar(mundo.cristales_recogidos == numero + 1, "El HUD cuenta el cristal del " + etiqueta)
			var regreso := ruta.duplicate()
			regreso.reverse()
			ok = true
			for k in regreso.size() - 1:
				ok = ok and await saltar_entre(regreso[k], regreso[k + 1], k == 0)
			comprobar(ok and mundo.estado == mundo.Estado.JUGANDO, "Vuelta por el " + etiqueta)
			jugador.salud.llenar()
		# 3 de desvío + 1 en el descanso antes del clímax.
		comprobar(mundo.interfaz.contador_cristales.text.ends_with("3 / 4"), "Mapa %d: el HUD muestra 3 / 4" % semilla)
		var de_desvio := get_nodes_in_group("cristales").filter(func(c): return c.name != "CristalDescanso")
		comprobar(de_desvio.filter(func(c): return not c.tomado).is_empty(), "Mapa %d: los cristales no se recargan" % semilla)

	# Agachado quema x1.5 (en suelo firme, sin viento).
	calor_activo = true
	await cargar()
	jugador.global_position = mundo.get_node("IslaInicial").global_position + Vector3(2, 2.6, 2)
	await pasos(20)
	Input.action_press("agacharse")
	await pasos(5)
	var inicio: float = jugador.salud.actual
	await pasos(5 * Engine.physics_ticks_per_second)
	Input.action_release("agacharse")
	var esperado: float = jugador.salud.maximo / mundo.calor.segundos_de_resistencia * 5.0 * 1.5
	var gasto: float = inicio - jugador.salud.actual
	comprobar(absf(gasto - esperado) < 1.0, "Agachado quema x1.5 (%.1f de %.1f)" % [gasto, esperado])
	print("CRISTALES: %d comprobaciones; %d fallos" % [comprobaciones, fallos])
	paused = false
	quit(1 if fallos else 0)
