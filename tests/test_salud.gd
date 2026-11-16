extends "res://tests/test_partida.gd"

# Salud y calor: desgaste constante, más rápido con viento, recuperación con el
# orbe, derrota por calor y por lava, y que el HUD reaccione por señales.


func segundos(s: float) -> void:
	await pasos(int(s * Engine.physics_ticks_per_second))


func _ejecutar() -> void:
	await cargar()
	var salud: Salud = jugador.salud
	var barra: BarraSalud = mundo.interfaz.barra_salud
	var calor = mundo.calor
	# Viento sin fuerza: solo interesa si el jugador está dentro de la zona.
	for zona in get_nodes_in_group("zonas_viento"):
		zona.aceleracion = 0.0
	# Las zonas de viento están sobre plataformas inestables: que no se derrumben aquí.
	for plataforma in get_nodes_in_group("inestables"):
		plataforma.set_physics_process(false)
	comprobar(barra.visible and barra.barra.value > salud.maximo * 0.99, "La barra empieza llena y visible")

	# Desgaste en suelo firme: 10 s deben quitar 10/90 de la barra.
	var antes := salud.actual
	await segundos(10.0)
	var gasto := antes - salud.actual
	var esperado: float = salud.maximo / calor.segundos_de_resistencia * 10.0
	comprobar(absf(gasto - esperado) < 1.0, "El calor quema a ritmo constante (%.1f de %.1f)" % [gasto, esperado])
	comprobar(is_equal_approx(barra.barra.value, salud.actual), "La barra sigue a la salud")

	# En una zona de viento quema el doble.
	var zona: Node3D = get_nodes_in_group("zonas_viento")[0]
	jugador.global_position = zona.global_position
	jugador.velocity = Vector3.ZERO
	await pasos(3)
	antes = salud.actual
	await segundos(5.0)
	var gasto_viento := antes - salud.actual
	comprobar(absf(gasto_viento - esperado) < 1.0, "Con viento quema el doble (%.1f en 5 s)" % gasto_viento)

	# Pausa: el calor no avanza.
	await tecla(KEY_ESCAPE)
	antes = salud.actual
	await segundos(3.0)
	comprobar(is_equal_approx(salud.actual, antes), "En pausa no quema")
	await tecla(KEY_ESCAPE)

	# El orbe restaura toda la salud y la barra destella.
	await recoger()
	comprobar(salud.actual > salud.maximo * 0.99, "El orbe llena la salud")
	comprobar(barra.tween_destello != null and barra.tween_destello.is_running(), "La barra destella al recuperarse")

	# Salud crítica: la barra late.
	salud.danar(salud.maximo * 0.8)
	await pasos(2)
	comprobar(barra.tween_latido != null, "Con poca salud la barra late")
	salud.curar(salud.maximo)
	await pasos(2)
	comprobar(barra.tween_latido == null and barra.barra.modulate == Color.WHITE, "Al recuperarse deja de latir")

	# Derrota por calor.
	salud.danar(salud.maximo - 1.0)
	await segundos(2.0)
	comprobar(paused and mundo.estado == mundo.Estado.DERROTA, "Salud agotada por calor = derrota")
	comprobar(mundo.interfaz.titulo.text == "El calor te venció", "Mensaje de derrota por calor")
	comprobar(mundo.origen.tiene_objeto and jugador.objeto_llevado == "", "El orbe vuelve a su pedestal")
	comprobar(mundo.interfaz.boton_vestibulo.visible, "La derrota ofrece volver al vestíbulo")

	# Derrota por lava: vacía la salud de golpe.
	await cargar()
	jugador.global_position = Vector3(30, -1, 0)
	await pasos(10)
	comprobar(mundo.estado == mundo.Estado.DERROTA and mundo.interfaz.titulo.text == "Has caído", "La lava vacía la salud y da derrota")
	comprobar(jugador.salud.actual == 0.0 and mundo.interfaz.barra_salud.barra.value == 0.0, "La barra queda en cero")

	# Volver al vestíbulo: allí no hay calor ni barra.
	mundo.interfaz.boton_vestibulo.pressed.emit()
	await pasos(10)
	comprobar(current_scene.scene_file_path == "res://niveles/spawn/spawn.tscn" and not paused, "El botón lleva al vestíbulo")
	comprobar(not current_scene.interfaz.barra_salud.visible, "En el vestíbulo no hay barra de calor")
	print("SALUD: %d comprobaciones; %d fallos" % [comprobaciones, fallos])
	paused = false
	quit(1 if fallos else 0)
