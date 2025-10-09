extends DirectionalLight3D
class_name CelestialBody3D

enum CelestialProp{
	COLOR = 0, 
	INTENSITY = 1, 
	SIZE = 2, 
	TEXTURE = 3,
	MIE_COLOR = 4, 
	MIE_INTENSITY = 5, 
	MIE_ANISOTROPY = 6, 
	INTENSITY_MULTIPLIER = 7,
}

signal direction_changed(value)
signal property_changed(type, value)

@export
var intensity_multiplier: float = 1.0:
	get: return intensity_multiplier
	set(value):
		intensity_multiplier = value
		_on_intensity_multiplier()

#region Body
@export_group("Body")
@export
var body_color:=Color(1.0, 0.936, 0.766, 1.0):
	get: return body_color
	set(value):
		body_color = value
		property_changed.emit(CelestialProp.COLOR, body_color)

@export
var body_intensity: float = 1.0:
	get: return body_intensity
	set(value):
		body_intensity = value
		property_changed.emit(CelestialProp.INTENSITY, body_intensity)

@export
var body_size: float = 1.0:
	get: return body_size
	set(value):
		body_size = value
		property_changed.emit(CelestialProp.SIZE, body_size)
#endregion

#region Mie
@export_group("Mie")
@export_color_no_alpha
var mie_color:= Color.WHITE:
	get: return mie_color
	set(value):
		mie_color = value
		property_changed.emit(CelestialProp.MIE_COLOR, mie_color)

@export
var mie_intensity: float = 1.0:
	get: return mie_intensity
	set(value):
		mie_intensity = value
		property_changed.emit(CelestialProp.MIE_INTENSITY, mie_intensity)

@export_range(0.0, 0.9999)
var mie_anisotropy: float = 0.85:
	get: return mie_anisotropy
	set(value):
		mie_anisotropy = value
		property_changed.emit(CelestialProp.MIE_ANISOTROPY, mie_anisotropy)
#endregion

#region Lighting
@export_group("Lighting")
@export
var lighting_color:= Color(0.984314, 0.843137, 0.788235):
	get: return lighting_color
	set(value):
		lighting_color = value
		_update_light_color()

@export
var lighting_gradient: Gradient = null:
	get: return _lighting_gradient
	set(value):
		if is_instance_valid(value):
			_lighting_gradient = value
			_connect_light_gradient_changed()
		elif _lighting_gradient_is_valid:
			_disconnect_light_gradient_changed()
			_lighting_gradient = null
		_update_light_color()

@export
var lighting_energy: float = 1.0:
	get: return lighting_energy
	set(value):
		lighting_energy = value
		_update_light_energy()

@export
var lighting_energy_curve: Curve = null:
	get: return _lighting_energy_curve
	set(value):
		if is_instance_valid(value):
			_lighting_energy_curve = value
			_connect_light_curve_changed()
		elif _lighting_gradient_is_valid:
			_disconnect_light_curve_changed()
			_lighting_energy_curve = null
		_update_light_energy()

@export
var lighting_enable_shadows: bool = true:
	get: return lighting_enable_shadows
	set(value):
		lighting_enable_shadows = value
		_update_light_energy()

@export
var auto_disabale_shadows: bool = true:
	get: return auto_disabale_shadows
	set(value):
		auto_disabale_shadows = value
		_update_light_energy()
#endregion

var _lighting_gradient: Gradient = null
var _lighting_energy_curve: Curve = null

var direction: Vector3:
	get: return -(basis * Vector3.FORWARD)

var _lighting_gradient_is_valid: bool:
	get: return is_instance_valid(_lighting_gradient)

var _lighting_energy_curve_is_valid: bool:
	get: return is_instance_valid(_lighting_energy_curve)

#region Godot Node Overrides
func _init() -> void:
	initialize_props()

func _notification(what: int) -> void:
	_on_notification(what)
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_params()
	if what == NOTIFICATION_ENTER_TREE:
		_on_enter_tree()
	if what == NOTIFICATION_EXIT_TREE:
		_on_exit_tree()

func initialize_props() -> void:
	lighting_color = lighting_color
	lighting_gradient = lighting_gradient
	lighting_energy = lighting_energy
	lighting_energy_curve = lighting_energy_curve
	intensity_multiplier = intensity_multiplier
	_update_params()

func _on_enter_tree() -> void:
	intensity_multiplier = intensity_multiplier

func _on_exit_tree() -> void:
	pass

func _on_notification(what: int) -> void:
	pass
#endregion

#region Connections
func _connect_light_gradient_changed() -> void:
	if !lighting_gradient.changed.is_connected(_on_light_gradient_changed):
		lighting_gradient.changed.connect(_on_light_gradient_changed)

func _disconnect_light_gradient_changed() -> void:
	if lighting_gradient.changed.is_connected(_on_light_gradient_changed):
		lighting_gradient.changed.disconnect(_on_light_gradient_changed)

func _connect_light_curve_changed() -> void:
	if !lighting_energy_curve.changed.is_connected(_on_light_curve_changed):
		lighting_energy_curve.changed.connect(_on_light_curve_changed)

func _disconnect_light_curve_changed() -> void:
	if lighting_energy_curve.changed.is_connected(_on_light_curve_changed):
		lighting_energy_curve.changed.disconnect(_on_light_curve_changed)
#endregion

#region Signal Events
func _on_intensity_multiplier() -> void:
	_update_light_energy()
	property_changed.emit(CelestialProp.INTENSITY_MULTIPLIER, intensity_multiplier)

func _on_light_gradient_changed() -> void:
	_update_light_color()

func _on_light_curve_changed() -> void:
	_update_light_energy()
#endregion

# Update
func _update_params() -> void:
	direction_changed.emit(direction)
	_update_light_color()
	_update_light_energy()

#region Lighting
func _update_light_color() -> void:
	if _lighting_gradient_is_valid:
		light_color = lighting_gradient.sample(
			UnivSkyUtil.interpolate_by_above(direction.y)
		)
	else:
		light_color = lighting_color

func _update_light_energy() -> void:
	light_energy = _get_light_energy() * intensity_multiplier
	if lighting_enable_shadows:
		if auto_disabale_shadows:
			shadow_enabled = true if light_energy > 0.0 else false
		else:
			shadow_enabled = true
	else:
		shadow_enabled = false

func _get_light_energy() -> float:
	if not _lighting_energy_curve_is_valid:
		var uMuS = (atan(max(direction.y, -0.1975) * tan(1.386)) / 1.1 + (1.0 - 0.26));
		uMuS = clamp(uMuS-0.3, 0.0, 1.0)
		return lerp(0.0, lighting_energy, uMuS)
	return lighting_energy_curve.sample(UnivSkyUtil.interpolate_full(direction.y))
#endregion
