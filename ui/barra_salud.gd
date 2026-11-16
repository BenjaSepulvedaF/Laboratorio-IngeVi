class_name BarraSalud
extends HBoxContainer

# Barra de resistencia al calor del HUD. No consulta la salud cada frame: se
# conecta a la señal "cambiada" del componente Salud y solo se actualiza cuando
# este le avisa (patrón Observer).
#
# Feedback reactivo:
#  - el color pasa de ámbar a rojo a medida que baja;
#  - con poca salud la barra late (parpadea) para advertir el peligro;
#  - al recuperar salud destella en celeste.

const UMBRAL_CRITICO := 0.25
const COLOR_LLENA := Color(1.0, 0.72, 0.2)
const COLOR_VACIA := Color(0.9, 0.12, 0.05)
const COLOR_CURA := Color(0.45, 0.95, 1.0)

var barra: ProgressBar
var porcentaje: Label
var relleno: StyleBoxFlat
var tween_latido: Tween
var tween_destello: Tween


func _init() -> void:
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icono := Label.new()
	icono.text = "CALOR"
	icono.add_theme_font_size_override("font_size", 14)
	icono.add_theme_color_override("font_color", Color(1, 0.7, 0.35))
	add_child(icono)
	barra = ProgressBar.new()
	barra.custom_minimum_size = Vector2(260, 18)
	barra.show_percentage = false
	barra.step = 0.0 # sin redondeo: la barra baja de forma continua
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fondo_barra := StyleBoxFlat.new()
	fondo_barra.bg_color = Color(0.08, 0.05, 0.05, 0.85)
	fondo_barra.set_corner_radius_all(4)
	fondo_barra.border_color = Color(1, 0.6, 0.3, 0.5)
	fondo_barra.set_border_width_all(1)
	relleno = StyleBoxFlat.new()
	relleno.bg_color = COLOR_LLENA
	relleno.set_corner_radius_all(4)
	barra.add_theme_stylebox_override("background", fondo_barra)
	barra.add_theme_stylebox_override("fill", relleno)
	add_child(barra)
	porcentaje = Label.new()
	porcentaje.add_theme_font_size_override("font_size", 14)
	porcentaje.custom_minimum_size = Vector2(44, 0)
	add_child(porcentaje)
	visible = false # el vestíbulo no tiene calor: la barra solo aparece al conectarla


func conectar(salud: Salud) -> void:
	salud.cambiada.connect(_on_salud_cambiada)
	visible = true
	_on_salud_cambiada(salud.actual, salud.maximo, 0.0)


func _on_salud_cambiada(actual: float, maximo: float, diferencia: float) -> void:
	var fraccion := actual / maximo
	barra.max_value = maximo
	barra.value = actual
	porcentaje.text = "%d%%" % ceili(fraccion * 100.0)
	relleno.bg_color = COLOR_VACIA.lerp(COLOR_LLENA, fraccion)
	_latir(fraccion <= UMBRAL_CRITICO and actual > 0.0)
	if diferencia > 1.0:
		_destellar()


# Parpadeo continuo mientras la salud está en zona crítica.
func _latir(activo: bool) -> void:
	if activo == (tween_latido != null):
		return
	if activo:
		tween_latido = create_tween().set_loops()
		tween_latido.tween_property(barra, "modulate", Color(1.6, 0.6, 0.6), 0.25)
		tween_latido.tween_property(barra, "modulate", Color.WHITE, 0.25)
	else:
		tween_latido.kill()
		tween_latido = null
		barra.modulate = Color.WHITE


# Destello breve al recuperar salud.
func _destellar() -> void:
	if tween_destello:
		tween_destello.kill()
	porcentaje.modulate = COLOR_CURA * 1.5
	tween_destello = create_tween()
	tween_destello.tween_property(porcentaje, "modulate", Color.WHITE, 0.6)
	var brillo := relleno.bg_color
	relleno.bg_color = COLOR_CURA
	tween_destello.parallel().tween_property(relleno, "bg_color", brillo, 0.6)
