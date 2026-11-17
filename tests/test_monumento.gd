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

	print("MONUMENTO: %d comprobaciones; %d fallos" % [comprobaciones, fallos])
	paused = false
	quit(1 if fallos else 0)
