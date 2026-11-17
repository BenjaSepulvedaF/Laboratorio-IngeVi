extends "res://tests/test_partida.gd"

# Monumento de los orbes y flujo entre escenas: llevar el orbe del volcán al
# vestíbulo, colocarlo (victoria, porque es el último nivel), jugar de nuevo,
# portales sellados y el volcán tras entregar su orbe.

const VESTIBULO := "res://niveles/spawn/spawn.tscn"
const ORBE_LLEVADO := &"volcan_orbe_llevado"


func ir_al_vestibulo(con_orbe: String) -> Node:
	paused = false
	if con_orbe != "":
		set_meta(ORBE_LLEVADO, con_orbe)
	change_scene_to_file(VESTIBULO)
	await pasos(10)
	jugador = current_scene.jugador
	return current_scene


func junto_al_pedestal(vestibulo: Node, id: String) -> void:
	var pedestal: Node3D = vestibulo.monumento.pedestales[id].nodo
	jugador.global_position = pedestal.global_position + Vector3(0, 1.05, 1.2)
	jugador.velocity = Vector3.ZERO
	await pasos(5)


func _ejecutar() -> void:
	progreso().reiniciar()

	# Del volcán al vestíbulo con el orbe, por el portal Inicio.
	await cargar()
	await recoger()
	jugador.global_position = mundo.get_node("PuertaSpawn").global_position + Vector3(0, 1.2, 0)
	await pasos(15)
	comprobar(current_scene.scene_file_path == VESTIBULO, "El portal Inicio lleva al vestíbulo")
	jugador = current_scene.jugador
	comprobar(jugador.orbe_id == "volcan" and jugador.visual.orbe_espalda.visible, "El orbe cruza el portal")
	comprobar(current_scene.interfaz.objetivo.text.begins_with("Coloca el orbe"), "Objetivo: colocarlo en el monumento")
	comprobar(not has_meta(ORBE_LLEVADO), "La marca del orbe se consume al llegar")

	# El monumento tiene un pedestal por nivel, vacío al principio.
	var vestibulo := current_scene
	comprobar(vestibulo.monumento.pedestales.size() == progreso().NIVELES.size(), "Un pedestal por nivel")
	var orbe_pedestal: Node3D = vestibulo.monumento.pedestales["volcan"].orbe
	comprobar(not orbe_pedestal.visible, "El pedestal empieza vacío")

	# Colocar el orbe: animación, luego victoria (el volcán es el último nivel).
	await junto_al_pedestal(vestibulo, "volcan")
	comprobar(vestibulo.monumento.pedestales["volcan"].etiqueta.text.begins_with("[E]"), "El pedestal ofrece colocar el orbe")
	await tecla(KEY_E)
	comprobar(jugador.estado == jugador.Estado.BLOQUEADO and jugador.orbe_id == "", "El orbe sale de la espalda")
	await pasos(150)
	comprobar(progreso().entregado("volcan") and orbe_pedestal.visible, "El orbe queda en su pedestal")
	comprobar(paused and vestibulo.interfaz.menu_actual == "VICTORIA", "Colocar el último orbe es la victoria")
	comprobar(vestibulo.interfaz.boton_principal.text == "Jugar de nuevo", "La victoria ofrece jugar de nuevo")
	await tecla(KEY_ESCAPE)
	comprobar(paused and vestibulo.interfaz.menu_actual == "VICTORIA", "Esc no cierra la victoria")

	# Jugar de nuevo: el progreso se borra y el pedestal vuelve a estar vacío.
	vestibulo.interfaz.boton_principal.pressed.emit()
	await pasos(10)
	vestibulo = current_scene
	jugador = vestibulo.jugador
	comprobar(not paused and progreso().entregados.is_empty(), "Jugar de nuevo borra el progreso")
	comprobar(not vestibulo.monumento.pedestales["volcan"].orbe.visible and jugador.orbe_id == "", "Jugar de nuevo vacía el monumento")

	# Sin orbe, el pedestal no hace nada.
	await junto_al_pedestal(vestibulo, "volcan")
	await tecla(KEY_E)
	await pasos(10)
	comprobar(not progreso().entregado("volcan") and jugador.estado == jugador.Estado.NORMAL, "Sin orbe no se coloca nada")

	# Portal sellado hasta entregar el orbe que pide (para el siguiente nivel).
	var puerta: Area3D = load("res://objetos/puerta/puerta.tscn").instantiate()
	puerta.nivel_requerido = "volcan"
	puerta.texto = "Cueva"
	vestibulo.add_child(puerta)
	puerta.position = Vector3(8, 0, 8)
	await pasos(2)
	comprobar(not puerta.activa and puerta.get_node("Etiqueta").text.contains("Sellado"), "Un portal con requisito empieza sellado")
	progreso().entregar("volcan")
	await pasos(2)
	comprobar(puerta.activa and puerta.get_node("Etiqueta").text == "Cueva", "Entregar el orbe abre el portal")

	# El volcán con su orbe ya entregado: el pedestal queda vacío.
	await cargar()
	comprobar(not mundo.origen.tiene_objeto and jugador.objeto_llevado == "", "Tras entregarlo, el orbe no vuelve al volcán")
	comprobar(mundo.interfaz.objetivo.text.begins_with("Ya colocaste"), "Objetivo tras entregar el orbe")
	progreso().reiniciar()

	# Título del nivel al entrar por el portal: el calor y el cronómetro esperan.
	await cargar(true, -1, true)
	var tarjeta: Control = mundo.interfaz.tarjeta_titulo
	comprobar(tarjeta.visible and mundo.interfaz.tarjeta_nombre.text == "El corazón del volcán", "Al entrar aparece el título del nivel")
	comprobar(not mundo.calor.activo and not progreso().cronometro_activo, "Durante el título no corren el calor ni el tiempo")
	var inicio_titulo: Vector3 = jugador.global_position
	Input.action_press("mover_adelante")
	await pasos(60)
	Input.action_release("mover_adelante")
	comprobar(jugador.global_position.distance_to(inicio_titulo) < 0.05, "Durante el título el jugador no puede moverse")
	# Pausar durante el título lo congela.
	await tecla(KEY_ESCAPE)
	var opacidad: float = tarjeta.modulate.a
	await pasos(180)
	comprobar(tarjeta.visible and is_equal_approx(tarjeta.modulate.a, opacidad), "Pausar congela el título")
	await tecla(KEY_ESCAPE)
	comprobar(jugador.estado == jugador.Estado.BLOQUEADO, "Reanudar durante el título sigue sin dejar moverse")
	await pasos(int(6.6 * Engine.physics_ticks_per_second))
	comprobar(not tarjeta.visible and mundo.calor.activo and progreso().cronometro_activo, "Tras el título empiezan el calor y el cronómetro")
	comprobar(jugador.estado == jugador.Estado.NORMAL, "Tras el título el jugador puede moverse")
	comprobar(mundo.interfaz.cronometro.visible and mundo.interfaz.cronometro.text.begins_with("Tiempo"), "El HUD muestra el cronómetro")
	var antes_reloj: float = progreso().tiempo
	await pasos(int(2.0 * Engine.physics_ticks_per_second))
	var avance: float = progreso().tiempo - antes_reloj
	comprobar(absf(avance - 2.0) < 0.1 and mundo.interfaz.cronometro.text == "Tiempo  " + progreso().formato(progreso().tiempo), "El cronómetro avanza y el HUD lo muestra (%.2f s en 2 s)" % avance)
	await tecla(KEY_ESCAPE)
	var congelado: float = progreso().tiempo
	await pasos(120)
	comprobar(is_equal_approx(progreso().tiempo, congelado), "En pausa el cronómetro se detiene")
	await tecla(KEY_ESCAPE)
	# Reintentar no repite el título y vuelve el cronómetro a 0.
	jugador.salud.vaciar("lava")
	await pasos(3)
	mundo.interfaz.boton_principal.pressed.emit()
	await pasos(5)
	mundo = current_scene
	comprobar(not mundo.interfaz.tarjeta_titulo.visible and progreso().tiempo < 0.5, "Reintentar no repite el título y reinicia el tiempo")

	# El título se puede saltar con la acción de saltar.
	progreso().cancelar_cronometro()
	await cargar(true, -1, true)
	await pasos(30)
	var salto := InputEventAction.new()
	salto.action = "saltar"
	salto.pressed = true
	Input.parse_input_event(salto)
	await pasos(2)
	salto = InputEventAction.new()
	salto.action = "saltar"
	salto.pressed = false
	Input.parse_input_event(salto)
	await pasos(int(0.6 * Engine.physics_ticks_per_second))
	comprobar(not mundo.interfaz.tarjeta_titulo.visible and jugador.estado == jugador.Estado.NORMAL and mundo.calor.activo, "Saltar el título deja jugar de inmediato")

	# Flechas: cada una apunta a la plataforma siguiente; con el orbe, a la anterior.
	await cargar()
	var generador = mundo.get_node("Parkour")
	var ruta: Array = [mundo.get_node("IslaInicial")] + Array(generador.apoyos) + Array(generador.torre)
	var bien_ida := 0
	for k in ruta.size() - 1:
		var flecha: Node3D = ruta[k].get_node("Flecha")
		var hacia: Vector3 = ruta[k + 1].global_position - ruta[k].global_position
		hacia.y = 0
		var apunta: Vector3 = -flecha.global_basis.z
		apunta.y = 0
		if flecha.visible and apunta.normalized().dot(hacia.normalized()) > 0.99:
			bien_ida += 1
	comprobar(bien_ida == ruta.size() - 1, "Las %d flechas apuntan a la plataforma siguiente (%d bien)" % [ruta.size() - 1, bien_ida])
	comprobar(not ruta[ruta.size() - 1].get_node("Flecha").visible, "La cima no tiene flecha de ida")
	comprobar(generador.get_children().filter(func(n): return n.name.begins_with("Desvio") and n.has_node("Flecha")).is_empty(), "Los desvíos no tienen flechas")
	await recoger()
	var bien_vuelta := 0
	for k in range(1, ruta.size()):
		var flecha: Node3D = ruta[k].get_node("Flecha")
		var hacia: Vector3 = ruta[k - 1].global_position - ruta[k].global_position
		hacia.y = 0
		var apunta: Vector3 = -flecha.global_basis.z
		apunta.y = 0
		if flecha.visible and apunta.normalized().dot(hacia.normalized()) > 0.99:
			bien_vuelta += 1
	comprobar(bien_vuelta == ruta.size() - 1, "Con el orbe, las flechas apuntan de regreso (%d bien)" % bien_vuelta)
	var flecha_isla: Node3D = ruta[0].get_node("Flecha")
	var al_portal: Vector3 = mundo.get_node("PuertaSpawn").global_position - ruta[0].global_position
	al_portal.y = 0
	var apunta_isla: Vector3 = -flecha_isla.global_basis.z
	apunta_isla.y = 0
	comprobar(apunta_isla.normalized().dot(al_portal.normalized()) > 0.99, "En la isla, la flecha de regreso apunta al portal Inicio")

	# La victoria muestra el tiempo final.
	progreso().reiniciar()
	progreso().iniciar_cronometro(true)
	progreso().tiempo = 125.4
	vestibulo = await ir_al_vestibulo("volcan")
	await junto_al_pedestal(vestibulo, "volcan")
	await tecla(KEY_E)
	await pasos(150)
	comprobar(vestibulo.interfaz.descripcion.text.contains("Tiempo: 2:0"), "La victoria muestra el tiempo del intento (el cronómetro siguió hasta colocar el orbe)")
	comprobar(not progreso().cronometro_activo, "Colocar el último orbe detiene el cronómetro")
	progreso().reiniciar()

	print("MONUMENTO: %d comprobaciones; %d fallos" % [comprobaciones, fallos])
	paused = false
	quit(1 if fallos else 0)
