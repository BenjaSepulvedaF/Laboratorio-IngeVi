extends Node3D

# Partida del nivel del volcán: inicio, pausa y derrota, y dónde está el orbe.
# El nivel termina al volver por el portal "Inicio" con el orbe: la entrega (y la
# victoria) ocurren en el monumento del vestíbulo, igual para todos los niveles.

enum Estado { INICIO, JUGANDO, PAUSA, DERROTA }
const ID_NIVEL := "volcan"
const AUTO_INICIO := &"volcan_inicio_directo"
const ORBE_LLEVADO := &"volcan_orbe_llevado"
const VESTIBULO := "res://niveles/spawn/spawn.tscn"
# Marca de "Reintentar": la recarga no repite el título y el cronómetro vuelve a 0.
const REINTENTO := &"volcan_reintento"
# Título del nivel (elemento narrativo, opción D): sitúa al jugador al entrar.
const CAPITULO := "C A P Í T U L O   I"
const NOMBRE := "El corazón del volcán"
const CONTEXTO := "El orbe que mantenía vivo el monumento yace en lo alto del volcán.\nCruza la lava antes de que el calor te consuma, y tráelo de vuelta."

var estado: Estado = Estado.INICIO
var estado_antes_pausa: Estado = Estado.JUGANDO
var cristales_recogidos := 0
var reintento := false
# Mientras se muestra el título, el jugador no se mueve y el calor y el
# cronómetro esperan: así nadie gana ventaja mientras lee.
var en_titulo := false
@onready var jugador = $Jugador
@onready var origen = $AltarRecoger
@onready var interfaz = $Interfaz
@onready var calor = $Calor


func _ready() -> void:
	origen.interaccion_solicitada.connect(_interactuar)
	# Toda muerte pasa por la salud: caer fuera del mapa o a la lava la vacía, y el
	# calor la va gastando. Cuando llega a cero, la salud avisa y se pierde.
	jugador.caida.connect(func(): jugador.salud.vaciar("caida"))
	jugador.salud.agotada.connect(_morir)
	calor.salud = jugador.salud
	calor.jugador = jugador
	# Los cristales los crea el generador del parkour (que ya corrió su _ready).
	var cristales := get_tree().get_nodes_in_group("cristales")
	interfaz.mostrar_cristales(0, cristales.size())
	for cristal in cristales:
		cristal.recogido.connect(_on_cristal_recogido.bind(cristales.size()))
	interfaz.conectar_salud(jugador.salud)
	jugador.agarre_cambiado.connect(interfaz.mostrar_agarre)
	$Lava/ZonaLetal.body_entered.connect(_tocar_lava)
	interfaz.jugar_solicitado.connect(_jugar)
	interfaz.reinicio_solicitado.connect(reiniciar)
	interfaz.pausa_solicitada.connect(_alternar_pausa)
	interfaz.permite_vestibulo = true
	interfaz.vestibulo_solicitado.connect(_volver_al_vestibulo)
	# Si se volvió por una puerta cargando el orbe, se conserva en la espalda. La marca
	# se consume aquí: reintentar o reiniciar recargan la escena y el orbe vuelve al origen.
	var llevado: String = get_tree().get_meta(ORBE_LLEVADO, "")
	if get_tree().has_meta(ORBE_LLEVADO):
		get_tree().remove_meta(ORBE_LLEVADO)
	if Progreso.entregado(ID_NIVEL):
		_establecer_orbe("entregado")
	else:
		_establecer_orbe("espalda" if llevado == ID_NIVEL else "origen")
	reintento = get_tree().has_meta(REINTENTO)
	if reintento:
		get_tree().remove_meta(REINTENTO)
	if get_tree().has_meta(AUTO_INICIO):
		get_tree().remove_meta(AUTO_INICIO)
		if not reintento:
			_mostrar_titulo()
		_jugar()
	else:
		jugador.bloquear()
		_menu(Estado.INICIO)


func _mostrar_titulo() -> void:
	en_titulo = true
	interfaz.mostrar_titulo(CAPITULO, NOMBRE, CONTEXTO)
	interfaz.titulo_terminado.connect(_fin_titulo, CONNECT_ONE_SHOT)


func _fin_titulo() -> void:
	en_titulo = false
	if estado == Estado.JUGANDO:
		jugador.desbloquear()
		calor.activo = true
		_iniciar_cronometro()


func _iniciar_cronometro() -> void:
	# Un reintento empieza de 0; si se vuelve desde el vestíbulo con el intento en
	# curso (por ejemplo, con el orbe), el cronómetro sigue corriendo.
	Progreso.iniciar_cronometro(reintento)
	reintento = false


func _jugar() -> void:
	if estado == Estado.PAUSA:
		estado = estado_antes_pausa
	else:
		estado = Estado.JUGANDO
		if en_titulo:
			jugador.bloquear()
		else:
			jugador.desbloquear()
			_iniciar_cronometro()
	get_tree().paused = false
	calor.activo = estado == Estado.JUGANDO and not en_titulo
	interfaz.cerrar_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _menu(nuevo: Estado) -> void:
	estado = nuevo
	calor.activo = false
	interfaz.mostrar_menu(Estado.keys()[nuevo])
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true


func _alternar_pausa() -> void:
	if estado == Estado.PAUSA:
		interfaz.reproducir_pausa()
		_jugar()
	elif estado == Estado.JUGANDO:
		interfaz.reproducir_pausa()
		estado_antes_pausa = estado
		_menu(Estado.PAUSA)


func _on_cristal_recogido(_cristal: Node, total: int) -> void:
	cristales_recogidos += 1
	interfaz.mostrar_cristales(cristales_recogidos, total)


func _tocar_lava(body: Node3D) -> void:
	if body == jugador:
		jugador.salud.vaciar("lava")


func _morir(causa: String = "") -> void:
	if estado != Estado.JUGANDO:
		return
	jugador.bloquear()
	jugador.reproducir_muerte()
	if not Progreso.entregado(ID_NIVEL):
		_establecer_orbe("origen")
	interfaz.causa_derrota = causa
	_menu(Estado.DERROTA)


# Este es el único punto que decide dónde existe el orbe del nivel:
# "origen" (en su pedestal), "espalda" (lo lleva el jugador) o "entregado"
# (ya está en el monumento del vestíbulo: el pedestal queda vacío).
func _establecer_orbe(lugar: String) -> void:
	origen.establecer_objeto(lugar == "origen")
	jugador.equipar_orbe(lugar == "espalda", ID_NIVEL)
	origen.habilitado = lugar == "origen"
	origen.actualizar_etiqueta()
	interfaz.mostrar_objetivo(lugar)
	# Con el orbe en la espalda, las flechas del camino apuntan de regreso.
	$Parkour.mostrar_ruta(lugar == "espalda")


func _interactuar(altar: Node3D, actor: CharacterBody3D) -> void:
	if estado != Estado.JUGANDO or actor != jugador or not jugador.puede_interactuar():
		return
	if altar == origen and origen.tiene_objeto and jugador.objeto_llevado == "":
		_establecer_orbe("espalda")
		jugador.play_grab()
		jugador.reproducir_orbe()
		# El orbe es la gran recompensa a mitad del recorrido: restaura toda la salud.
		jugador.salud.llenar()


func _volver_al_vestibulo() -> void:
	# Volver desde un menú cuenta como abandonar el intento: el orbe no se lleva.
	get_tree().set_meta(ORBE_LLEVADO, "")
	Progreso.cancelar_cronometro()
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(VESTIBULO)


func reiniciar() -> void:
	get_tree().set_meta(AUTO_INICIO, true)
	get_tree().set_meta(REINTENTO, true)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var error := get_tree().reload_current_scene()
	if error != OK:
		get_tree().remove_meta(AUTO_INICIO)
		push_error("No se pudo reiniciar el escenario: " + error_string(error))
		_menu(Estado.DERROTA)
