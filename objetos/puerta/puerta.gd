extends Area3D

# Puerta que lleva a otro nivel. Al entrar marca el inicio directo, para que el nivel
# empiece sin mostrar de nuevo el menú de inicio.
@export var escena := "res://niveles/mundo/mundo.tscn"
@export var marca_inicio := true
@export var texto := "Puerta"
# Si no está vacío, la puerta está sellada hasta que se coloque en el monumento
# el orbe de ese nivel (id de Progreso.NIVELES). Ej.: el portal de la cueva
# lleva nivel_requerido = "volcan".
@export var nivel_requerido := ""

const AUTO_INICIO := &"volcan_inicio_directo"
# Cambiar de escena destruye al jugador; esta marca lleva el orbe (su id de nivel,
# o "" si no lleva ninguno) a la escena siguiente.
const ORBE_LLEVADO := &"volcan_orbe_llevado"
const SONIDO_PORTAL = preload("res://assets/audio/portal.wav")
# portal.wav dura ~6 s; se desvanece antes para no tapar el inicio del otro nivel.
const DURACION_SONIDO := 2.5

var activa := true


func _ready() -> void:
	$Etiqueta.text = texto
	body_entered.connect(_on_body_entered)
	if nivel_requerido != "" and not Progreso.entregado(nivel_requerido):
		_sellar()
		Progreso.orbe_entregado.connect(_on_orbe_entregado)


# Sellada: no deja pasar, el portal se ve oscuro y el cartel dice qué falta.
func _sellar() -> void:
	activa = false
	var portal := $Portal as CSGBox3D
	var sellado := (portal.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	sellado.albedo_color = Color(0.25, 0.05, 0.03, 0.85)
	sellado.emission = Color(0.6, 0.12, 0.04)
	sellado.emission_energy_multiplier = 0.6
	portal.material_override = sellado
	$Luz.light_color = Color(1, 0.3, 0.1)
	$Luz.light_energy = 0.5
	var datos := Progreso.datos(nivel_requerido)
	$Etiqueta.text = texto + "\nSellado: coloca el " + str(datos.get("orbe", "orbe anterior")).to_lower()


func _on_orbe_entregado(id: String) -> void:
	if id != nivel_requerido:
		return
	activa = true
	($Portal as CSGBox3D).material_override = null
	$Luz.light_color = Color(0.4, 0.7, 1)
	$Luz.light_energy = 1.5
	$Etiqueta.text = texto


func _on_body_entered(body: Node3D) -> void:
	if not activa or not body.is_in_group("jugador"):
		return
	activa = false
	if marca_inicio:
		get_tree().set_meta(AUTO_INICIO, true)
	get_tree().set_meta(ORBE_LLEVADO, body.orbe_id)
	# Suelto: el cambio de escena destruye la puerta y cortaría el sonido.
	SonidoSuelto.reproducir(get_tree(), SONIDO_PORTAL, -3.0, DURACION_SONIDO)
	get_tree().change_scene_to_file.call_deferred(escena)
