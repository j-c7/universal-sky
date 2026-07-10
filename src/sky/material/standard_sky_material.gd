@tool
extends SkyMaterialBase
class_name StandardSkyMaterial

const SHADER:= preload(
	"res://addons/universal-sky/src/sky/shaders/standard-sky/univsky_standard_sky.gdshader"
)

const _DEFAULT_BACKGROUND_TEXTURE:= preload(
	"res://addons/universal-sky/assets/textures/milky-way/Milkyway.jpg"
)

const _DEFAULT_STARS_FIELD_TEXTURE:= preload(
	"res://addons/universal-sky/assets/textures/milky-way/StarField.jpg"
)

#region Shader Param Names
const TONEMAP_LEVEL_PARAM:= &"tonemap_level"
const EXPOSURE_PARAM:= &"exposure"
const HORIZON_OFFSET_PARAM:= &"horizon_offset"
const DEBANDING_LEVEL_PARAM:= &"debanding_level"

const ATM_CONTRAST_PARAM:= &"atm_contrast"
const ATM_DAY_INTENSITY_PARAM:= &"atm_day_intensity"
const ATM_RAYLEIGH_LEVEL_PARAM:= &"atm_rayleigh_level"
const ATM_THICKNESS_PARAM:= &"atm_thickness"

const ATM_BETA_RAY_PARAM:= &"atm_beta_ray"
const ATM_BETA_MIE_PARAM:= &"atm_beta_mie"
const ATM_GROUND_COLOR_PARAM:= &"atm_ground_color"

const SUN_UMUS_PARAM:= &"sun_uMuS"

const DAY_TINT_PARAM:= &"atm_day_tint"
const NIGHT_TINT_PARAM:= &"atm_night_tint"

const DEEP_SPACE_BACKGROUND_COLOR_PARAM:= &"background_color"
const DEEP_SPACE_BACKGROUND_TEXTURE_PARAM:= &"background_texture"
const DEEP_SPACE_BACKGROUND_INTENSITY_PARAM:= &"background_intensity"
const DEEP_SPACE_BACKGROUND_CONTRAST_PARAM:= &"background_contrast"
const STARS_FIELD_COLOR_PARAM:= &"stars_field_color"
const STARS_FIELD_INTENSITY_PARAM:= &"stars_field_intensity"
const STARS_FIELD_TEXTURE_PARAM:= &"stars_field_texture"
const STARS_SCINTILLATION_PARAM:= &"stars_scintillation"
const STARS_SCINTILLATION_SPEED_PARAM:= &"stars_scintillation_speed"

const ENABLE_DYNAMIC_CLOUDS_PARAM:= &"enable_dynamic_clouds"
const DYNAMIC_CLOUDS_TEXTURE_PARAM:= &"dynamic_clouds_texture"
const DYNAMIC_CLOUDS_TEXTURE2_PARAM:= &"dynamic_clouds_texture2"
const DYNAMIC_CLOUDS_COVERAGE_PARAM:= &"dynamic_clouds_coverage"
const DYNAMIC_CLOUDS_ABSORPTION_PARAM:= &"dynamic_clouds_absorption"
const DYNAMIC_CLOUDS_DENSITY_PARAM:= &"dynamic_clouds_density"
const DYNAMIC_CLOUDS_INTENSITY_PARAM:= &"dynamic_clouds_intensity"
const DYNAMIC_CLOUDS_DIRECTION_PARAM:= &"dynamic_clouds_direction"
const DYNAMIC_CLOUDS_SIZE_PARAM:= &"dynamic_clouds_size"
const DYNAMIC_CLOUDS_UV_PARAM:= &"dynamic_clouds_uv"

const ENABLE_CLOUDS_PANORAMA_PARAM:= &"enable_clouds_panorama"
const CLOUDS_PANORAMA_PARAM:= &"clouds_panorama"
const CLOUDS_PANORAMA_INTENSITY_PARAM:= &"clouds_panorama_intensity"
const CLOUDS_PANORAMA_SPEED_PARAM:= &"clouds_panorama_speed"
#endregion

#region Atmospheric Scaterring Const
# Index of the air refraction.
const n: float = 1.0003

# Index of the air refraction ˆ 2.
const n2: float = 1.00060009

# Molecular Density.
const N: float = 2.545e25

# Depolatization factor for standard air.
const pn: float = 0.035
#endregion

#region General Settings
@export_group("General Settings")
@export_range(0.0, 1.0)
var tonemap_level: float = 0.0:
	get: return tonemap_level
	set(value):
		tonemap_level = value
		RenderingServer.material_set_param(
			material.get_rid(), TONEMAP_LEVEL_PARAM, tonemap_level
		)
		emit_changed()

@export_range(0.0, 1.0)
var debanding_level: float = 1.0:
	get: return debanding_level
	set(value):
		debanding_level = value
		RenderingServer.material_set_param(
			material.get_rid(), DEBANDING_LEVEL_PARAM, debanding_level
		)
		emit_changed()

@export
var exposure: float = 1.0:
	get: return exposure
	set(value):
		exposure = value
		RenderingServer.material_set_param(
			material.get_rid(), EXPOSURE_PARAM, exposure
		)
		emit_changed()

@export_range(-1.0, 1.0)
var horizon_offset: float = 0.0:
	get: return horizon_offset
	set(value):
		horizon_offset = value
		RenderingServer.material_set_param(
			material.get_rid(), HORIZON_OFFSET_PARAM, horizon_offset
		)
		emit_changed()
#endregion

#region Atmosphere
@export_group("Atmosphere", "atm_")
@export_range(0.0, 1.0)
var atm_contrast: float = 0.1:
	get: return atm_contrast
	set(value):
		atm_contrast = value
		RenderingServer.material_set_param(
			material.get_rid(), ATM_CONTRAST_PARAM, atm_contrast
		)
		emit_changed()

@export_subgroup("Rayleigh", "atm_")
@export
var atm_wavelenghts:= Vector3(680.0, 550.0, 440.0):
	get: return atm_wavelenghts
	set(value):
		atm_wavelenghts = value
		_set_beta_ray()

@export
var atm_rayleigh_level: float = 1.0:
	get: return atm_rayleigh_level
	set(value):
		atm_rayleigh_level = value
		RenderingServer.material_set_param(
			material.get_rid(), ATM_RAYLEIGH_LEVEL_PARAM, atm_rayleigh_level
		)
		emit_changed()

@export
var atm_thickness: float = 1.0:
	get: return atm_thickness
	set(value):
		atm_thickness = value
		RenderingServer.material_set_param(
			material.get_rid(), ATM_THICKNESS_PARAM, atm_thickness
		)
		emit_changed()

@export_subgroup("Mie", "atm_")
@export
var atm_mie: float = 0.07:
	get: return atm_mie
	set(value):
		atm_mie = value
		_set_beta_mie()
		emit_changed()

@export
var atm_turbidity: float = 0.001:
	get: return atm_turbidity
	set(value):
		atm_turbidity = value
		_set_beta_mie()
		emit_changed()

@export_subgroup("Day", "atm_")
@export
var atm_day_intensity: float = 10.0:
	get: return atm_day_intensity
	set(value):
		atm_day_intensity = value
		RenderingServer.material_set_param(
			material.get_rid(), ATM_DAY_INTENSITY_PARAM, atm_day_intensity * sun_intensity_multiplier
		)
		emit_changed()

@export
var atm_day_gradient: Gradient:
	get: return _atm_day_gradient
	set(value):
		if is_instance_valid(value):
			_atm_day_gradient = value
			_connect_atm_day_gradient_changed()
		elif is_instance_valid(_atm_day_gradient):
			_disconnect_atm_day_gradient_changed()
			_atm_day_gradient = null
		_set_atm_day_tint()
		emit_changed()

@export_subgroup("Night", "atm_")
@export
var atm_night_intensity: float = 0.345:
	get: return atm_night_intensity
	set(value):
		atm_night_intensity = value
		_set_atm_night_tint()
		emit_changed()

@export
var atm_enable_night_scattering: bool = false:
	get: return atm_enable_night_scattering
	set(value):
		atm_enable_night_scattering = value
		_update_sun_direction(sun_direction)
		_update_moon_direction(moon_direction)
		emit_changed()

@export
var atm_night_tint:= Color(0.57, 0.754, 1.0):
	get: return atm_night_tint
	set(value):
		atm_night_tint = value
		_set_atm_night_tint()
		emit_changed()

@export_subgroup("Ground", "atm_")
@export
var atm_ground_color:= Color(0.543, 0.543, 0.543): # Color(0.204, 0.345, 0.467):
	get: return atm_ground_color
	set(value):
		atm_ground_color = value
		var c = atm_ground_color * 5.0
		RenderingServer.material_set_param(
			material.get_rid(), ATM_GROUND_COLOR_PARAM, 
				c.srgb_to_linear() if is_compatibility else c
		)
		_sync_volumetric_cloud_lighting()
		emit_changed()
#endregion

#region Deep Space
@export_group("Deep Space")
@export_subgroup('Background')
@export
var background_color:= Color(1.0, 1.0, 1.0, 1.0):
	get: return background_color
	set(value):
		background_color = value
		RenderingServer.material_set_param(
			material.get_rid(), DEEP_SPACE_BACKGROUND_COLOR_PARAM, 
				background_color.srgb_to_linear() if is_compatibility else background_color
		)
		emit_changed()

@export
var background_intensity: float = 0.1:
	get: return background_intensity
	set(value):
		background_intensity = value
		RenderingServer.material_set_param(
			material.get_rid(), DEEP_SPACE_BACKGROUND_INTENSITY_PARAM, background_intensity
		)
		emit_changed()

@export_range(0.0, 1.0)
var background_contrast: float = 0.561:
	get: return background_contrast
	set(value):
		background_contrast = value
		RenderingServer.material_set_param(
			material.get_rid(), DEEP_SPACE_BACKGROUND_CONTRAST_PARAM, background_contrast
		)
		emit_changed()

@export 
var use_custom_bg_texture: bool = false:
	get: return use_custom_bg_texture
	set(value):
		use_custom_bg_texture = value
		if value:
			background_texture = background_texture
		else:
			background_texture = _DEFAULT_BACKGROUND_TEXTURE
		notify_property_list_changed()

@export
var background_texture: Texture = null:
	get: return background_texture
	set(value):
		background_texture = value
		material.set_shader_parameter(DEEP_SPACE_BACKGROUND_TEXTURE_PARAM, background_texture)
		emit_changed()

@export_subgroup('StarsField')
@export
var stars_field_color:= Color.WHITE:
	get: return stars_field_color
	set(value):
		stars_field_color = value
		RenderingServer.material_set_param(
			material.get_rid(), STARS_FIELD_COLOR_PARAM, 
				stars_field_color.srgb_to_linear() if is_compatibility else stars_field_color
		)
		emit_changed()

@export
var stars_field_intensity: float = 1.0:
	get: return stars_field_intensity
	set(value):
		stars_field_intensity = value
		RenderingServer.material_set_param(
			material.get_rid(), STARS_FIELD_INTENSITY_PARAM, stars_field_intensity
		)
		emit_changed()

@export
var use_custom_stars_field_texture: bool = false:
	get: return use_custom_stars_field_texture
	set(value):
		use_custom_stars_field_texture = value
		if value:
			stars_field_texture = stars_field_texture
		else:
			stars_field_texture = _DEFAULT_STARS_FIELD_TEXTURE
		notify_property_list_changed()

@export
var stars_field_texture: Texture = null:
	get: return stars_field_texture
	set(value):
		stars_field_texture = value
		material.set_shader_parameter(STARS_FIELD_TEXTURE_PARAM, stars_field_texture)
		emit_changed()

@export_range(0.0, 1.0)
var stars_scintillation: float = 0.75:
	get: return stars_scintillation
	set(value):
		stars_scintillation = value
		RenderingServer.material_set_param(
			material.get_rid(), STARS_SCINTILLATION_PARAM, stars_scintillation
		)
		emit_changed()

@export_range(0.0, 10.0)
var stars_scintillation_speed: float = 1.0:
	get: return stars_scintillation_speed
	set(value):
		stars_scintillation_speed = value
		RenderingServer.material_set_param(
			material.get_rid(), STARS_SCINTILLATION_SPEED_PARAM, stars_scintillation_speed
		)
		emit_changed()
#endregion

#region Clouds
@export_group('Volumetric Clouds')
## Forward+ volumetric clouds. Use one resource per sky material.
@export
var volumetric_clouds: VolumetricClouds:
	get: return volumetric_clouds
	set(value):
		if volumetric_clouds == value:
			if is_instance_valid(volumetric_clouds):
				volumetric_clouds.attach(material)
				_sync_volumetric_cloud_lighting()
			return
		if is_instance_valid(volumetric_clouds):
			volumetric_clouds.detach()
		volumetric_clouds = value
		if is_instance_valid(volumetric_clouds):
			volumetric_clouds.attach(material)
			_sync_volumetric_cloud_lighting()
		emit_changed()

@export_group('Dynamic Clouds')
@export
var enable_dynamic_clouds: bool = false:
	get: return enable_dynamic_clouds
	set(value):
		enable_dynamic_clouds = value
		RenderingServer.material_set_param(
			material.get_rid(), ENABLE_DYNAMIC_CLOUDS_PARAM, enable_dynamic_clouds
		)
		emit_changed()

@export
var dynamic_clouds_texture: Texture2D = null:
	get: return dynamic_clouds_texture
	set(value):
		dynamic_clouds_texture = value
		material.set_shader_parameter(DYNAMIC_CLOUDS_TEXTURE_PARAM, dynamic_clouds_texture)
		emit_changed()

@export
var dynamic_clouds_texture2: Texture2D = null:
	get: return dynamic_clouds_texture2
	set(value):
		dynamic_clouds_texture2 = value
		material.set_shader_parameter(DYNAMIC_CLOUDS_TEXTURE2_PARAM, dynamic_clouds_texture2)
		emit_changed()
@export
var dynamic_clouds_coverage:= 0.4:
	get: return dynamic_clouds_coverage
	set(value):
		dynamic_clouds_coverage = value
		RenderingServer.material_set_param(
			material.get_rid(), DYNAMIC_CLOUDS_COVERAGE_PARAM, dynamic_clouds_coverage
		)
		emit_changed()

@export
var dynamic_clouds_absorption:= 1.0:
	get: return dynamic_clouds_absorption
	set(value):
		dynamic_clouds_absorption = value
		RenderingServer.material_set_param(
			material.get_rid(), DYNAMIC_CLOUDS_ABSORPTION_PARAM, dynamic_clouds_absorption
		)
		emit_changed()

@export
var dynamic_clouds_density: float = 2.0:
	get: return dynamic_clouds_density
	set(value):
		dynamic_clouds_density = value
		RenderingServer.material_set_param(
			material.get_rid(), DYNAMIC_CLOUDS_DENSITY_PARAM, dynamic_clouds_density
		)
		emit_changed()

@export
var dynamic_clouds_intensity: float = 1.0:
	get: return dynamic_clouds_intensity
	set(value):
		dynamic_clouds_intensity = value
		RenderingServer.material_set_param(
			material.get_rid(), DYNAMIC_CLOUDS_INTENSITY_PARAM, dynamic_clouds_intensity
		)
		emit_changed()

@export
var dynamic_clouds_direction:= Vector2(0.005, 0.005):
	get: return dynamic_clouds_direction
	set(value):
		dynamic_clouds_direction = value
		RenderingServer.material_set_param(
			material.get_rid(), DYNAMIC_CLOUDS_DIRECTION_PARAM, dynamic_clouds_direction
		)
		emit_changed()

@export
var dynamic_clouds_size: float = 1.0:
	get: return dynamic_clouds_size
	set(value):
		dynamic_clouds_size = value
		RenderingServer.material_set_param(
			material.get_rid(), DYNAMIC_CLOUDS_SIZE_PARAM, dynamic_clouds_size
		)
		emit_changed()

@export
var dynamic_clouds_uv:= Vector2(0.1, 0.1):
	get: return dynamic_clouds_uv
	set(value):
		dynamic_clouds_uv = value
		RenderingServer.material_set_param(
			material.get_rid(), DYNAMIC_CLOUDS_UV_PARAM, dynamic_clouds_uv
		)
		emit_changed()

@export_group('Clouds Panorama')
@export
var enable_clouds_panorama: bool = false:
	get: return enable_clouds_panorama
	set(value):
		enable_clouds_panorama = value
		RenderingServer.material_set_param(
			material.get_rid(), ENABLE_CLOUDS_PANORAMA_PARAM, enable_clouds_panorama
		)
		emit_changed()

@export 
var clouds_panorama: Texture2D = null:
	get: return clouds_panorama
	set(value):
		clouds_panorama = value
		material.set_shader_parameter(CLOUDS_PANORAMA_PARAM, clouds_panorama)
		emit_changed()

@export
var clouds_panorama_intensity: float = 1.0:
	get: return clouds_panorama_intensity
	set(value):
		clouds_panorama_intensity = value
		RenderingServer.material_set_param(
			material.get_rid(), CLOUDS_PANORAMA_INTENSITY_PARAM, clouds_panorama_intensity
		)
		emit_changed()

@export
var clouds_panorama_speed: float = 0.005:
	get: return clouds_panorama_speed
	set(value):
		clouds_panorama_speed = value
		RenderingServer.material_set_param(
			material.get_rid(), CLOUDS_PANORAMA_SPEED_PARAM, clouds_panorama_speed
		)
		emit_changed()
#endregion

var _atm_day_gradient: Gradient = null
var _volumetric_light_direction:= Vector3.UP
var _volumetric_light_color:= Color.WHITE
var _volumetric_light_energy: float = 1.0

#region Setup
func _on_init() -> void:
	super()
	material.shader = SHADER
	initialize_params()

func _initialize_params() -> void:
	super()
	tonemap_level = tonemap_level
	debanding_level = debanding_level
	exposure = exposure
	horizon_offset = horizon_offset
	
	atm_contrast = atm_contrast
	atm_wavelenghts = atm_wavelenghts
	atm_rayleigh_level = atm_rayleigh_level
	atm_thickness = atm_thickness
	atm_mie = atm_mie
	atm_turbidity = atm_turbidity
	atm_day_intensity = atm_day_intensity
	atm_day_gradient = atm_day_gradient
	atm_night_intensity = atm_night_intensity
	atm_enable_night_scattering = atm_enable_night_scattering
	atm_night_tint = atm_night_tint
	atm_ground_color = atm_ground_color
	
	deep_space_aligment_matrix = deep_space_aligment_matrix
	deep_space_rotation_matrix = deep_space_rotation_matrix

	background_color = background_color
	use_custom_bg_texture = use_custom_bg_texture
	background_texture = background_texture
	background_intensity = background_intensity
	background_contrast = background_contrast
	
	stars_field_color = stars_field_color
	stars_field_intensity = stars_field_intensity
	use_custom_stars_field_texture = use_custom_stars_field_texture
	stars_field_texture = stars_field_texture
	stars_scintillation = stars_scintillation
	stars_scintillation_speed = stars_scintillation_speed

	volumetric_clouds = volumetric_clouds
	
	enable_dynamic_clouds = enable_dynamic_clouds
	dynamic_clouds_texture = dynamic_clouds_texture
	dynamic_clouds_texture2 = dynamic_clouds_texture2
	dynamic_clouds_coverage = dynamic_clouds_coverage
	dynamic_clouds_absorption = dynamic_clouds_absorption
	dynamic_clouds_density = dynamic_clouds_density
	dynamic_clouds_intensity = dynamic_clouds_intensity
	dynamic_clouds_direction = dynamic_clouds_direction
	dynamic_clouds_size = dynamic_clouds_size
	dynamic_clouds_uv = dynamic_clouds_uv
	
	enable_clouds_panorama = enable_clouds_panorama
	clouds_panorama = clouds_panorama
	clouds_panorama_intensity = clouds_panorama_intensity
	clouds_panorama_speed = clouds_panorama_speed

func _validate_property(property: Dictionary) -> void:
	if not use_custom_bg_texture && property.name == "background_texture":
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if not use_custom_stars_field_texture && property.name == "stars_field_texture":
		property.usage &= ~PROPERTY_USAGE_EDITOR

func _compatibility_changed() -> void:
	super()
	_set_atm_day_tint()
	_set_atm_night_tint()
	atm_ground_color = atm_ground_color
	background_color = background_color
	stars_field_color = stars_field_color
#endregion

#region Connections
func _connect_atm_day_gradient_changed() -> void:
	if !atm_day_gradient.changed.is_connected(_set_atm_day_tint):
		atm_day_gradient.changed.connect(_set_atm_day_tint)

func _disconnect_atm_day_gradient_changed() -> void:
	if atm_day_gradient.changed.is_connected(_set_atm_day_tint):
		atm_day_gradient.changed.disconnect(_set_atm_day_tint)
#endregion

#region Direction
func _get_celestial_uMuS(dir: Vector3) -> float:
	return (atan(max(dir.y, -0.1975) * tan(1.386)) / 1.1 + (1.0 - 0.26));

func _update_sun_direction(p_direction: Vector3) -> void:
	super(p_direction)
	_volumetric_light_direction = p_direction
	_set_sun_uMuS()
	_set_atm_day_tint()
	_set_atm_night_tint()
	_sync_volumetric_cloud_lighting()

func _update_moon_direction(p_direction: Vector3) -> void:
	super(p_direction)
	_set_sun_uMuS()
	_set_atm_night_tint()
	_sync_volumetric_cloud_lighting()

func _set_sun_uMuS() -> void:
	RenderingServer.material_set_param(
		material.get_rid(), SUN_UMUS_PARAM, _get_celestial_uMuS(sun_direction)
	)
	emit_changed()
#endregion

#region Intensity
func _update_sun_color(p_color: Color) -> void:
	super(p_color)
	_volumetric_light_color = p_color
	_sync_volumetric_cloud_lighting()

func _update_sun_intensity(p_intensity: float) -> void:
	super(p_intensity)
	_volumetric_light_energy = p_intensity
	_sync_volumetric_cloud_lighting()

func _update_sun_intensity_multiplier(p_multiplier: float) -> void:
	super(p_multiplier)
	atm_day_intensity = atm_day_intensity
	_sync_volumetric_cloud_lighting()

func _update_sun_eclipse_intensity(p_intensity: float) -> void:
	super(p_intensity)
	_set_atm_day_tint()
	_sync_volumetric_cloud_lighting()

func _update_moon_intensity_multiplier(p_multiplier: float) -> void:
	super(p_multiplier)
	atm_night_intensity = atm_night_intensity
	_sync_volumetric_cloud_lighting()
#endregion

## Passes the Sun3D light values to the clouds.
func set_volumetric_cloud_lighting(
		p_direction: Vector3,
		p_color: Color,
		p_energy: float
	) -> void:
	_volumetric_light_direction = p_direction
	_volumetric_light_color = p_color
	_volumetric_light_energy = p_energy
	_sync_volumetric_cloud_lighting()


func _sync_volumetric_cloud_lighting() -> void:
	if not is_instance_valid(volumetric_clouds):
		return
	var day_tint:= _atm_day_gradient.sample(
		UnivSkyUtil.interpolate_by_above(sun_direction.y)
	) if is_instance_valid(_atm_day_gradient) else Color.WHITE
	var day_strength:= clampf(_get_celestial_uMuS(sun_direction) - 0.2, 0.0, 1.0)
	var night_strength:= _get_atm_night_intensity()
	var ambient_color:= day_tint * maxf(0.04, day_strength)
	ambient_color += atm_night_tint * night_strength
	volumetric_clouds.set_lighting(
		_volumetric_light_direction,
		_volumetric_light_color.srgb_to_linear(),
		_volumetric_light_energy * sun_eclipse_intensity,
		ambient_color.srgb_to_linear(),
		atm_ground_color.srgb_to_linear()
	)

#region Atmospheric Scattering
func _compute_wavelenghts_lambda(value: Vector3) -> Vector3:
	return value * 1e-9

func _compute_wavelenghts(value: Vector3, computeLambda: bool = false) -> Vector3:
	var k: float = 4.0
	var ret: Vector3 = value
	if computeLambda:
		ret = _compute_wavelenghts_lambda(ret)
	
	ret.x = pow(ret.x, k)
	ret.y = pow(ret.y, k)
	ret.z = pow(ret.z, k)
	return ret

func _compute_beta_ray(wavelenghts: Vector3) -> Vector3:
	var kr: float =  (8.0 * pow(PI, 3.0) * pow(n2 - 1.0, 2.0) * (6.0 + 3.0 * pn))
	var ret: Vector3 = 3.0 * N * wavelenghts * (6.0 - 7.0 * pn)
	ret.x = kr / ret.x
	ret.y = kr / ret.y
	ret.z = kr / ret.z
	return ret

func _compute_beta_mie(mie: float, turbidity: float) -> Vector3:
	var k: float = 434e-6
	return Vector3.ONE * mie * turbidity * k

func _set_beta_ray() -> void:
	var wls:= _compute_wavelenghts(atm_wavelenghts, true)
	var br:= _compute_beta_ray(wls)
	RenderingServer.material_set_param(
		material.get_rid(), ATM_BETA_RAY_PARAM, br
	)
	emit_changed()

func _set_beta_mie() -> void:
	var bm:= _compute_beta_mie(atm_mie, atm_turbidity)
	RenderingServer.material_set_param(
		material.get_rid(), ATM_BETA_MIE_PARAM, bm
	)
	emit_changed()

func _set_atm_day_tint() -> void:
	var c: Color = atm_day_gradient.sample(UnivSkyUtil.interpolate_by_above(sun_direction.y))\
		if is_instance_valid(atm_day_gradient) else Color.WHITE
	RenderingServer.material_set_param(
		material.get_rid(), DAY_TINT_PARAM,
		c.srgb_to_linear() if is_compatibility else c
	)
	emit_changed()

func _get_atm_night_intensity() -> float:
	var ret = 0.0
	if not atm_enable_night_scattering:
		ret =  clamp(_get_celestial_uMuS(-sun_direction), 0.0, 1.0)
	else:
		ret = clamp(_get_celestial_uMuS(moon_direction), 0.0, 1.0)
	
	return ret * atm_night_intensity * _get_atm_moon_phases_mul() * moon_intensity_multiplier

func _get_atm_moon_phases_mul() -> float:
	if atm_enable_night_scattering:
		return moon_phases_mul
	return 1.0

func _set_atm_night_tint() -> void:
	var tint:= atm_night_tint * _get_atm_night_intensity()
	RenderingServer.material_set_param(
		material.get_rid(), NIGHT_TINT_PARAM, tint.srgb_to_linear() if is_compatibility else tint
	)
	_update_moon_mie_intensity(moon_mie_intensity)
	emit_changed()
#endregion
