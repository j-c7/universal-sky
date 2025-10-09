@tool 
@icon("res://addons/universal-sky/assets/icons/godot/sun.svg")
extends CelestialBody3D
class_name Sun3D

signal updated_eclipse(value)

@export_group("Eclipse")
@export
var enable_solar_eclipse: bool = false:
	get: return enable_solar_eclipse
	set(value):
		enable_solar_eclipse = value
		_update_params()

@export
var eclipse_threshold: float = -0.01:
	get: return eclipse_threshold
	set(value):
		eclipse_threshold = value
		_update_params()

@export
var eclipse_slope: float = 200.0:
	get: return eclipse_slope
	set(value):
		eclipse_slope = value
		_update_params()

@export
var min_eclipse_intensity: float = 0.01:
	get: return min_eclipse_intensity
	set(value):
		min_eclipse_intensity = value
		_update_params()

var _moon: Moon3D:
	get: return _moon

var _moon_is_valid: bool:
	get: return is_instance_valid(_moon)

var eclipse_multiplier: float = 1.0:
	get: return eclipse_multiplier

# Godot Node Overrides
func initialize_props() -> void:
	super()
	body_color = Color(1, 0.7058, 0.4470)
	body_intensity = 10.0
	body_size = 1.0
	_update_eclipse()

#region Connections
func _connect_moon_signals() -> void:
	if not _moon.direction_changed.is_connected(_on_moon_direction_changed):
		_moon.direction_changed.connect(_on_moon_direction_changed)

func _disconnect_moon_signals() -> void:
	if _moon.direction_changed.is_connected(_on_moon_direction_changed):
		_moon.direction_changed.disconnect(_on_moon_direction_changed)
#endregion

# References
func set_moon(p_moon: Moon3D) -> void:
	if is_instance_valid(p_moon):
		_moon = p_moon
		_connect_moon_signals()
	else:
		_disconnect_moon_signals()
		_moon = null

# Signal Events
func _on_moon_direction_changed(p_value: Vector3) -> void:
	_update_eclipse()

# Update
func _update_params() -> void:
	_update_eclipse()
	super()

# Lighting
func _get_light_energy() -> float:
	return super() * eclipse_multiplier

func _update_eclipse() -> void:
	if not _moon_is_valid:
		return
	
	if enable_solar_eclipse:
		const celestialSizeBase = 0.017453293
		var sunSize = body_size * celestialSizeBase
		var moonSize = _moon.body_size * celestialSizeBase
		var threshold = eclipse_threshold - (-sunSize - moonSize)
		var factor = UnivSkyMath.angular_intensity_sig(
			direction, _moon.direction, threshold, eclipse_slope
		)
		
		factor = clamp(factor, min_eclipse_intensity, 1.0) \
			if sunSize <= moonSize + celestialSizeBase else clamp(factor, 0.9, 1.0)
		
		eclipse_multiplier = factor
	else:
		eclipse_multiplier = 1.0
	
	updated_eclipse.emit(eclipse_multiplier)
	
	_update_light_energy()
