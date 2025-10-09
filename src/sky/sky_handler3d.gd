@tool 
@icon("res://addons/universal-sky/assets/icons/sky.svg")
extends Node
class_name SkyHandler3D

const RENDERING_METHOD_PATH:= &"rendering/renderer/rendering_method"
const COMPATIBILITY_RENDER_METHOD_NAME:= &"gl_compatibility"

@export_group("Resources")
@export
var material: SkyMaterialBase:
	get: return material
	set(value):
		material = value
		if material_is_valid:
			_update_celestials_data()
			_initialize_material()
			_set_sky_material_to_enviro()
			_connect_enviro_changed()

#region Enviro
@export_group("Environment")
@export
var enviro_container: NodePath:
	get: return enviro_container
	set(value):
		enviro_container = value
		if enviro_container.is_empty():
			_disconnect_enviro_changed()
			if enviro_is_valid and enviro_sky_is_valid:
				_enviro.sky.sky_material = null
			_enviro = null
		else:
			var container = get_node_or_null(value)
			if is_instance_of(container, Camera3D) or \
				is_instance_of(container, WorldEnvironment):
					if container.environment == null:
						push_warning("enviroment resource not found")
						enviro_container = NodePath()
						return
					_enviro = container.environment
			_connect_enviro_changed()
			_set_sky_material_to_enviro()

@export_enum("Automatic", "High Quality", "Incremental", "Realtime")
var sky_process_mode: int = 2:
	get: return sky_process_mode
	set(value):
		sky_process_mode = value
		if enviro_is_valid and enviro_sky_is_valid:
			_enviro.sky.process_mode = sky_process_mode

@export_enum("32", "64", "128", "256", "512", "1024", "2048")
var sky_radiance_size: int = 1:
	get: return sky_radiance_size
	set(value):
		sky_radiance_size = value
		if enviro_is_valid and enviro_sky_is_valid:
			_enviro.sky.radiance_size = sky_radiance_size
#endregion

var _enviro: Environment = null

var sun: Sun3D:
	get: return sun

var moon: Moon3D:
	get: return moon

var enviro: Environment:
	get: return _enviro

var enviro_is_valid: bool:
	get: return is_instance_valid(_enviro)

var enviro_sky_is_valid: bool:
	get: return is_instance_valid(_enviro.sky)

var material_is_valid: bool:
	get: return is_instance_valid(material)

var sun_is_valid: bool:
	get: return is_instance_valid(sun)

var moon_is_valid: bool:
	get: return is_instance_valid(moon)

var deep_space_aligment_matrix:= Basis.from_euler(Vector3(13.045, -1.51, -2.07)):
	get: return deep_space_aligment_matrix
	set(value):
		deep_space_aligment_matrix = value
		if material_is_valid:
			material.deep_space_aligment_matrix = deep_space_aligment_matrix

var deep_space_rotation_matrix: Basis = Basis.from_euler(Vector3.ONE):
	get: return deep_space_rotation_matrix
	set(value):
		deep_space_rotation_matrix = value
		if material_is_valid:
			material.deep_space_rotation_matrix = deep_space_rotation_matrix

#region Godot Node Overrides
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			SkyInstances.set_instance(self)
			_connect_child_tree_signals()
			material = material
			enviro_container = enviro_container
			sky_process_mode = sky_process_mode
			sky_radiance_size = sky_radiance_size
		NOTIFICATION_EXIT_TREE:
			_disconnect_child_tree_signals()
			SkyInstances.remove_instance(self)
			if enviro_is_valid:
				_enviro.sky.sky_material = null
				_disconnect_enviro_changed()

func _get_configuration_warnings() -> PackedStringArray:
	if not sun_is_valid:
		return ["Sun unassigned"]
	if not moon_is_valid:
		return ["Moon unassigned"]
	if not material_is_valid:
		return ["Material unassigned"]
	return []
#endregion

#region Setup
func _initialize_material() -> void:
	material.initialize_params()
	if _get_rendering_method() == COMPATIBILITY_RENDER_METHOD_NAME:
		material.set_compatibility(true)
	else:
		material.set_compatibility(false)

func _get_rendering_method() -> String:
	return str(ProjectSettings.get_setting_with_override(RENDERING_METHOD_PATH))

func _set_sky_material_to_enviro() -> void:
	if not enviro_is_valid:
		_disconnect_enviro_changed()
		return
		
	_enviro.background_mode = Environment.BG_SKY
	if not enviro_sky_is_valid:
		_enviro.sky = Sky.new()
		_enviro.sky.process_mode = sky_process_mode
		_enviro.sky.radiance_size = sky_radiance_size
	
	if material_is_valid:
		_enviro.sky.sky_material = material.material
		_on_enviro_changed()
	else:
		_enviro.sky.sky_material = null
#endregion

#region Connections
func _connect_child_tree_signals() -> void:
	if not child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.connect(_on_child_entered_tree)
		
	if not child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.connect(_on_child_exiting_tree)

func _disconnect_child_tree_signals() -> void:
	if child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.disconnect(_on_child_entered_tree)
			
	if child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.disconnect(_on_child_exiting_tree)

func _connect_enviro_changed() -> void:
	pass

func _disconnect_enviro_changed() -> void:
	pass

func _connect_sun_signals() -> void:
	# Direction
	if not sun.direction_changed.is_connected(_on_sun_direction_changed):
		sun.direction_changed.connect(_on_sun_direction_changed)
	
	# Values
	if not sun.property_changed.is_connected(_on_sun_prop_changed):
		sun.property_changed.connect(_on_sun_prop_changed)
	
	# Eclipses
	if not sun.updated_eclipse.is_connected(_on_update_sun_eclipse):
		sun.updated_eclipse.connect(_on_update_sun_eclipse)

func _disconnect_sun_signals() -> void:
	# Direction
	if sun.direction_changed.is_connected(_on_sun_direction_changed):
		sun.direction_changed.disconnect(_on_sun_direction_changed)
	
	# Values
	if sun.property_changed.is_connected(_on_sun_prop_changed):
		sun.property_changed.disconnect(_on_sun_prop_changed)
	
	# Eclipses
	if sun.updated_eclipse.is_connected(_on_update_sun_eclipse):
		sun.updated_eclipse.disconnect(_on_update_sun_eclipse)

func _connect_moon_signals() -> void:
	# Direction
	if not moon.direction_changed.is_connected(_on_moon_direction_changed):
		moon.direction_changed.connect(_on_moon_direction_changed)
	
	# Values
	if not moon.property_changed.is_connected(_on_moon_prop_changed):
		moon.property_changed.connect(_on_moon_prop_changed)
	
	if not moon.yaw_offset_changed.is_connected(_on_moon_yaw_offset_changed):
		moon.yaw_offset_changed.connect(_on_moon_yaw_offset_changed)
	
	# Phases mul
	if not moon.updated_moon_phases_multiplier.is_connected(_on_updated_moon_phases_mul):
		moon.updated_moon_phases_multiplier.connect(_on_updated_moon_phases_mul)
	
	# Matrix
	if not moon.updated_moon_matrix.is_connected(_on_updated_moon_matrix):
		moon.updated_moon_matrix.connect(_on_updated_moon_matrix)

func _disconnect_moon_signals() -> void:
	# Direction
	if moon.direction_changed.is_connected(_on_moon_direction_changed):
		moon.direction_changed.disconnect(_on_moon_direction_changed)
	
	# Values
	if moon.property_changed.is_connected(_on_moon_prop_changed):
		moon.property_changed.disconnect(_on_moon_prop_changed)
	
	if moon.yaw_offset_changed.is_connected(_on_moon_yaw_offset_changed):
		moon.yaw_offset_changed.disconnect(_on_moon_yaw_offset_changed)
	
	# Phases mul
	if moon.updated_moon_phases_multiplier.is_connected(_on_updated_moon_phases_mul):
		moon.updated_moon_phases_multiplier.disconnect(_on_updated_moon_phases_mul)
	
	# Matrix
	if moon.updated_moon_matrix.is_connected(_on_updated_moon_matrix):
		moon.updated_moon_matrix.disconnect(_on_updated_moon_matrix)
	
#endregion

#region Signal Events
# Child
func _on_child_entered_tree(p_node: Node) -> void:
	if p_node is Sun3D and not sun_is_valid:
		sun = p_node
		if sun_is_valid:
			_connect_sun_signals()
			if moon_is_valid:
				sun.set_moon(moon)
				moon.set_sun(sun)
		
		_update_celestials_data()

	if p_node is Moon3D and not moon_is_valid:
		moon = p_node
		if moon_is_valid:
			_connect_moon_signals()
			if sun_is_valid:
				moon.set_sun(sun)
				sun.set_moon(moon)
		
		_update_celestials_data()

func _on_child_exiting_tree(p_node: Node) -> void:
	if p_node is Sun3D and p_node.get_instance_id() == sun.get_instance_id():
		_disconnect_sun_signals()
		if material_is_valid:
			material.initialize_params()
		if moon_is_valid:
			moon.set_sun(null)
		
		sun = null
	
	if p_node is Moon3D and p_node.get_instance_id() == moon.get_instance_id():
		_disconnect_moon_signals()
		if material_is_valid:
			material.initialize_params()
		if sun_is_valid:
			sun.set_moon(null)
		
		moon = null
	
	_update_celestials_data()

# Enviro
func _on_enviro_changed() -> void:
	pass

# Sun
func _on_sun_direction_changed(p_value: Vector3) -> void:
	if not material_is_valid or not sun_is_valid:
		return
	
	material.sun_direction = p_value

func _on_sun_prop_changed(p_type: int, p_value: Variant) -> void:
	if not material_is_valid or not sun_is_valid:
		return
	
	match(p_type):
		CelestialBody3D.CelestialProp.COLOR:
			material.sun_color = p_value
		CelestialBody3D.CelestialProp.INTENSITY:
			material.sun_intensity = p_value
		CelestialBody3D.CelestialProp.INTENSITY_MULTIPLIER:
			material.sun_intensity_multiplier = p_value
		CelestialBody3D.CelestialProp.SIZE:
			material.sun_size = p_value
		CelestialBody3D.CelestialProp.MIE_COLOR:
			material.sun_mie_color = p_value
		CelestialBody3D.CelestialProp.MIE_INTENSITY:
			material.sun_mie_intensity = p_value
		CelestialBody3D.CelestialProp.MIE_ANISOTROPY:
			material.sun_mie_anisotropy = p_value

# Moon
func _on_moon_direction_changed(p_value: Vector3) -> void:
	if not material_is_valid or not moon_is_valid:
		return
	
	material.moon_direction = p_value

func _on_updated_moon_phases_mul(p_value: float) -> void:
	material.moon_phases_mul = p_value

func _on_updated_moon_matrix(p_value: Basis) -> void:
	material.moon_matrix = p_value

func _on_moon_prop_changed(p_type: int, p_value: Variant) -> void:
	if not material_is_valid or not moon_is_valid:
		return
	
	match(p_type):
		Moon3D.CelestialProp.COLOR:
			material.moon_color = p_value
		Moon3D.CelestialProp.INTENSITY:
			material.moon_intensity = p_value
		Moon3D.CelestialProp.INTENSITY_MULTIPLIER:
			material.moon_intensity_multiplier = p_value
		Moon3D.CelestialProp.SIZE:
			material.moon_size = p_value
		Moon3D.CelestialProp.TEXTURE:
			material.moon_texture = p_value
		Moon3D.CelestialProp.MIE_COLOR:
			material.moon_mie_color = p_value
		Moon3D.CelestialProp.MIE_INTENSITY:
			material.moon_mie_intensity = p_value
		Moon3D.CelestialProp.MIE_ANISOTROPY:
			material.moon_mie_anisotropy = p_value

func _on_moon_yaw_offset_changed(p_value: float) -> void:
	if not material_is_valid or not moon_is_valid:
		return
	material.moon_texture_yaw_offset = p_value
#endregion

#region Update
func _update_celestials_data() -> void:
	_update_sun_data()
	_update_moon_data()

func _update_sun_data() -> void:
	if material_is_valid and sun_is_valid:
		sun.initialize_props()

func _update_moon_data() -> void:
	if material_is_valid and moon_is_valid:
		moon.initialize_props()

func _on_update_sun_eclipse(p_value: float) -> void:
	material.sun_eclipse_intensity = p_value
#endregion
