@tool @icon("res://addons/universal-sky/assets/icons/planetary.svg")
extends Node
class_name Planetary3D

enum CalculationsMode{
	SIMPLE = 0,
	REALISTIC
}

@export
var calculations_mode:= CalculationsMode.REALISTIC:
	get: return calculations_mode
	set(value):
		calculations_mode = value
		_update_celestial_coords()
		notify_property_list_changed()

@export_range(-12.0, 12.0)
var utc: float = 0.0:
	get: return utc
	set(value):
		utc = value
		_update_celestial_coords()

@export_range(-90.0, 90.0)
var latitude: float = 0.0:
	get: return latitude
	set(value):
		latitude = value
		_update_celestial_coords()

@export_range(-180.0, 180.0)
var longitude: float = 0.0:
	get: return longitude
	set(value):
		longitude = value
		_update_celestial_coords()

@export_range(-180.0, 180.0)
var world_orientation: float = -80.0:
	get: return world_orientation
	set(value):
		world_orientation = value
		_update_celestial_coords()

@export
var moon_coords_offset:= Vector2(180.0, 0.0):
	get: return moon_coords_offset
	set(value):
		moon_coords_offset = value
		_update_celestial_coords()

@export
var outer_space_aligment:= Vector3(13.045, -1.51, -2.07):
	get: return outer_space_aligment
	set(value):
		outer_space_aligment = value
		_update_celestial_coords()

var _sky_handler: SkyHandler3D = null
var _sun: Sun3D = null
var _moon: Moon3D = null

var _sun_altitude: float
var _sun_azimuth: float

var _moon_altitude: float
var _moon_azimuth: float

var _date_time: PlanetaryDateTime3D
var _timeline: float = 7.0
var _day: int = 1
var _month: int = 9
var _year: int = 2025

# Realistic cualculations private vars
var _sun_distance: float
var _true_sun_longitude: float 
var _mean_sun_longitude: float
var _sideral_time: float
var _local_sideral_time: float

var sky_handler_is_valid: bool:
	get: return is_instance_valid(_sky_handler)

var date_time_is_valid: bool:
	get: return is_instance_valid(_date_time)

var sun_is_valid: bool:
	get: return is_instance_valid(_sun)

var moon_is_valid: bool:
	get: return is_instance_valid(_moon)

var timeline_utc: float:
	get: return _timeline - utc

var sun_altitude: float:
	get: return _sun_altitude

var sun_azimuth: float:
	get: return _sun_azimuth

var sun_altitude_rad: float:
	get: return deg_to_rad(_sun_altitude)

var sun_azimuth_rad: float:
	get: return deg_to_rad(_sun_azimuth)

var moon_altitude: float:
	get: return _moon_altitude

var moon_azimuth: float:
	get: return _moon_azimuth

var moon_altitude_rad: float:
	get: return deg_to_rad(_moon_altitude)

var moon_azimuth_rad: float:
	get: return deg_to_rad(_moon_azimuth)

var latitude_rad: float:
	get: return deg_to_rad(latitude)

var longitude_rad: float:
	get: return deg_to_rad(longitude)

var world_orientation_rad: float:
	get: return deg_to_rad(world_orientation)

#region Godot Node Overrides
func _enter_tree() -> void:
	_connect_child_tree_signals()
	_initialize()

func _exit_tree() -> void:
	_disconnect_child_tree_signals()

func _initialize() -> void:
	calculations_mode = calculations_mode
	utc = utc
	latitude = latitude
	longitude = longitude
	moon_coords_offset = moon_coords_offset
	outer_space_aligment = outer_space_aligment
	if date_time_is_valid:
		_date_time.initialize_props()
		#for i in range(4):
			#_on_date_time_prop_changed(i)

func _validate_property(property: Dictionary) -> void:
	if calculations_mode == CalculationsMode.REALISTIC:
		if property.name == "world_orientation" || property.name == "moon_coords_offset":
			property.usage &= ~PROPERTY_USAGE_EDITOR
#endregion

#region Connections
# This node child enter and exit tree signals
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

# Sky handler child node  enter and exit signals.
func _connect_sky_handler_child_tree_signals() -> void:
	if not _sky_handler.child_entered_tree.is_connected(_on_sky_handler_child_entered_tree):
		_sky_handler.child_entered_tree.connect(_on_sky_handler_child_entered_tree)
	
	if not _sky_handler.child_exiting_tree.is_connected(_on_sky_handler_child_exiting_tree):
		_sky_handler.child_exiting_tree.connect(_on_sky_handler_child_exiting_tree)

func _disconnect_sky_handler_child_tree_signals() -> void:
	if _sky_handler.child_entered_tree.is_connected(_on_sky_handler_child_entered_tree):
		_sky_handler.child_entered_tree.disconnect(_on_sky_handler_child_entered_tree)
	
	if _sky_handler.child_exiting_tree.is_connected(_on_sky_handler_child_exiting_tree):
		_sky_handler.child_exiting_tree.disconnect(_on_sky_handler_child_exiting_tree)

# Datetime
func _connect_date_time_signals() -> void:
	if not _date_time.datetime_property_changed.is_connected(_on_date_time_prop_changed):
		_date_time.datetime_property_changed.connect(_on_date_time_prop_changed)

func _disconnect_date_time_signals() -> void:
	if _date_time.datetime_property_changed.is_connected(_on_date_time_prop_changed):
		_date_time.datetime_property_changed.disconnect(_on_date_time_prop_changed)
#endregion

#region Signal Events
func _on_child_entered_tree(p_node: Node) -> void:
	# Sky Handler
	if p_node is SkyHandler3D:
		_sky_handler = p_node as SkyHandler3D
		if sky_handler_is_valid:
			_connect_sky_handler_child_tree_signals()
			_initialize()
	
	# Date Time
	if p_node is PlanetaryDateTime3D:
		_date_time = p_node as PlanetaryDateTime3D
		if date_time_is_valid:
			_connect_date_time_signals()
			_initialize()

func _on_child_exiting_tree(p_node: Node) -> void:
	if sky_handler_is_valid:
		if p_node is SkyHandler3D and p_node.get_instance_id() == _sky_handler.get_instance_id():
			_disconnect_sky_handler_child_tree_signals()
			_sky_handler = null
	
	if date_time_is_valid:
		if p_node is PlanetaryDateTime3D and p_node.get_instance_id() == _date_time.get_instance_id():
			_disconnect_date_time_signals()
			_date_time = null

func _on_sky_handler_child_entered_tree(p_node: Node) -> void:
	if p_node is Sun3D:
		if _sky_handler.sun_is_valid:
			_sun = _sky_handler.sun
			await get_tree().create_timer(0.0001).timeout
			_initialize()
	if p_node is Moon3D:
		if _sky_handler.moon_is_valid:
			_moon = _sky_handler.moon
			await get_tree().create_timer(0.0001).timeout
			_initialize()

func _on_sky_handler_child_exiting_tree(p_node: Node) -> void:
	if not sky_handler_is_valid:
		return
	if p_node is Sun3D:
		if not _sky_handler.sun_is_valid:
			_sun = null
	if p_node is Moon3D:
		if not _sky_handler.moon_is_valid:
			_moon = null

func _on_date_time_prop_changed(p_param: int, p_value: Variant) -> void:
	match p_param:
		PlanetaryDateTime3D.DateTimeProp.TIMELINE:
			_timeline = p_value
		PlanetaryDateTime3D.DateTimeProp.DAY:
			_day = p_value
		PlanetaryDateTime3D.DateTimeProp.MONTH:
			_month = p_value
		PlanetaryDateTime3D.DateTimeProp.YEAR:
			_year = p_value
	_update_celestial_coords()
#endregion

#region Celestial Coords
func _update_celestial_coords() -> void:
	var sunQuat: Quaternion
	var moonQuat: Quaternion
	var outerSpaceTilt: Basis
	var outerSpaceRot: Basis
	var outerSpaceAligment: Basis = Basis.from_euler(outer_space_aligment)
	match calculations_mode:
		CalculationsMode.SIMPLE:
			var lonRad: float = deg_to_rad(longitude)
			var halfPI: float = PI * 0.5
			_local_sideral_time = (timeline_utc + lonRad) * 15
			
			# Sun
			_sun_altitude = _local_sideral_time
			_sun_azimuth = 90.0 - latitude
			
			sunQuat = Quaternion.from_euler(Vector3(0.0, world_orientation_rad, sun_azimuth_rad - halfPI)) \
			* Quaternion.from_euler(Vector3(sun_altitude_rad + halfPI, 0.0, 0.0))
			
			# Deep Space
			outerSpaceTilt = Basis.from_euler(
				Vector3(latitude_rad - halfPI, deg_to_rad(world_orientation + 80.0),  0.0)
			)
			
			outerSpaceRot = Basis.from_euler(
				Vector3(0.0, deg_to_rad(-_local_sideral_time), 0.0)
			)
			
			# Moon
			_moon_altitude = _local_sideral_time + moon_coords_offset.x
			_moon_azimuth = 90.0 - latitude + moon_coords_offset.y
			
			var moonDir: Vector3 = Quaternion.from_euler(Vector3(0.0, world_orientation_rad, moon_azimuth_rad - halfPI)) \
			* Quaternion.from_euler(Vector3(moon_altitude_rad + halfPI, 0.0, 0.0)) * Vector3.FORWARD
			
			var worldDir: Vector3 = outerSpaceTilt * outerSpaceRot * Vector3.RIGHT
			moonQuat = Basis.looking_at(moonDir, worldDir).get_rotation_quaternion()
		CalculationsMode.REALISTIC:
			# Sun
			_compute_realistic_sun_coords()
			sunQuat = Quaternion.from_euler(
				Vector3(-sun_altitude_rad, -sun_azimuth_rad - PI, 0.0)
			)
			
			# Deep Space
			outerSpaceTilt = Basis.from_euler(
				Vector3(deg_to_rad(latitude - 90), 0.0, 0.0)
			)
			
			outerSpaceRot = Basis.from_euler(
				Vector3(0.0, deg_to_rad(-_local_sideral_time), 0.0)
			)
			
			# Moon
			_compute_realistic_moon_coords()
			var moonDir: Vector3 = UnivSkyMath.celestials_coords_to_dir(-moon_altitude_rad, -moon_azimuth_rad)
			var worldDir:= outerSpaceTilt * outerSpaceRot * Vector3.RIGHT
			moonQuat = Basis.looking_at(moonDir, worldDir).get_rotation_quaternion()

	if sun_is_valid:
		_sun.quaternion = sunQuat
	
	if moon_is_valid:
		_moon.basis = moonQuat
	
	if sky_handler_is_valid:
		_sky_handler.deep_space_aligment_matrix = outerSpaceAligment
		_sky_handler.deep_space_rotation_matrix = outerSpaceTilt * outerSpaceRot

# Realistic Coords
# Math Formulas by Paul Schlyter, Stockholm, Sweden
# See:
# http://www.stjarnhimlen.se/comp/ppcomp.html
# http://stjarnhimlen.se/comp/tutorial.html
## Input Test: Latitude: 60.0, Longitude: 15.0, Utc: 0.0, 19-Abr-1990
## NOTE: To check in stelarium you need to enter your utc

## Reduce value to between 0 and 360 degrees.
func rev(p_value: float) -> float:
	return p_value - floori(p_value / 360.0) * 360.0
	
func sin_deg(deg: float) -> float:
	return sin(deg_to_rad(deg))

func cos_deg(deg: float) -> float:
	return cos(deg_to_rad(deg))

## See: 
## https://www.stjarnhimlen.se/comp/tutorial.html#4
## https://stjarnhimlen.se/comp/ppcomp.html#3
func _get_time_scale() -> float:
	var y = _year
	var m = _month
	var D = _day
	#var d: float = 367 * y - (7 * (y + ((m + 9) / 12))) / 4 + (275 * m) / 9 + D - 730530
	var d: int = 367 * y - 7 * (y + (m + 9) / 12) / 4 - 3 * \
		((y + (m * 9) / 7) / 100 + 1) / 4 + 275 * m / 9 + D - 730515
	
	return d + (_timeline / 24.0)

func _get_oblecl() -> float:
	return 23.4393 - 3.563e-7 * _get_time_scale()

func _compute_realistic_sun_coords() -> void:
	var timeScale: float = _get_time_scale()
	var oblectRad: float = deg_to_rad(_get_oblecl())
	#region Orbital Elements
	var w: float = 282.9404 + 4.70935e-5 * timeScale # Longitude of perihelion
	var a: float = 1.0 # mean distance, a.u.
	var e: float = 0.016709 - 1.151e-9 * timeScale # Eccentricity
	var M: float = 356.0470 + 0.9856002585 * timeScale # Mean anomaly.
	M = rev(M) 
	var MRad: float = deg_to_rad(M)
	#endregion
	
	#region Eccentric Anomaly
	var E: float = M + rad_to_deg(e) * sin(MRad) * (1 + e * cos(MRad))
	var ERad: float = deg_to_rad(E)
	var xv: float = cos(ERad) - e
	var yv: float = sin(ERad) * sqrt(1 - e * e)
	#endregion
	
	#region Distance and True Anomaly
	var r: float = sqrt(xv * xv + yv * yv)
	var v: float = rad_to_deg(atan2(yv, xv))
	_sun_distance = r
	#endregion
	
	#region Sun Longitude
	var lon: float = rev(v + w)
	var lonRad: float = deg_to_rad(lon)
	_true_sun_longitude = lonRad
	#endregion
	
	#region Ecliptic and ecuatorial coords.
	var xs: float = r * cos(lonRad)
	var ys: float = r * sin(lonRad) 
	var zs: float = 0.0
	
	var obleclCos: float = cos(oblectRad)
	var oblectSin: float = sin(oblectRad)
	
	var xequat: float = xs
	var yequat: float = ys * obleclCos - 0.0 * oblectSin
	var zequat: float = ys * oblectSin + 0.0 * obleclCos
	#endregion

	#region  Ascencion and declination.
	#var re: float = sqrt(xequat * xequat + yequat * yequat + zequat * zequat)
	var RA: float = rad_to_deg(atan2(yequat, xequat))
	var Decl: float = rad_to_deg(atan2(zequat, sqrt(xequat * xequat + yequat * yequat)))
	var DeclRad: float = deg_to_rad(Decl)
	#endregion
	
	#region Sideral time and hour angle.
	var L: float = rev(w + M)
	_mean_sun_longitude = L
	
	var GMST0: float = L/15 + 12 #(L + 180) / 15
	_sideral_time = GMST0 + timeline_utc + (longitude/15)
	
	_local_sideral_time = _sideral_time * 15
	var HA: float = _local_sideral_time - RA
	var HARad: float = deg_to_rad(HA) 
	#endregion
	
	#region Azimuth and Altitude
	var x: float = cos(HARad) * cos(DeclRad)
	var y: float = sin(HARad) * cos(DeclRad)
	var z: float = sin(DeclRad)
	var xhor = x * sin(latitude_rad) - z * cos(latitude_rad)
	var yhor = y
	var zhor = x * cos(latitude_rad) + z * sin(latitude_rad)
	var azimuth = rad_to_deg(atan2(yhor, xhor) + PI)
	var altitude = rad_to_deg(asin(zhor)) # atan2(zhor, sqrt(xhor * xhor + yhor * yhor))
	_sun_altitude = altitude
	_sun_azimuth = azimuth
	#endregion

func _compute_realistic_moon_coords() -> void:
	var timeScale: float = _get_time_scale()
	var oblectRad: float = deg_to_rad(_get_oblecl())
	#region Orbital Elements
	var N = 125.1228 - 0.0529538083 * timeScale # Long asc. node
	var i = 5.1454 # Inclination
	var w = 318.0634 + 0.1643573223 * timeScale # Arg. of perigee
	var a = 60.2666 # Mean distance
	var e = 0.054900 # Eccentricity
	var M = 115.3654 + 13.0649929509 * timeScale # Mean anomaly
	M = rev(M)
	var NRad: float = deg_to_rad(N)
	var wRad: float = deg_to_rad(w)
	var iRad: float = deg_to_rad(i)
	var MRad: float = deg_to_rad(M)
	var L: float = _mean_sun_longitude
	#endregion
	
	#region Excentrici Anomaly
	var E0: float = M + rad_to_deg(e) * sin(MRad) * (1 + e * cos(MRad))
	var E1: float = E0;
	while true:
		var E0Rad: float = deg_to_rad(E0)
		E1 = E0 - (E0 - rad_to_deg(e) * sin(E0Rad) - M) / (1 - e * cos(E0Rad))
		if abs(E1 - E0) < 0.005:
			break
		E0 = E1
	
	var E: float = E1
	var ERad: float = deg_to_rad(E)
	var xv: float = a * (cos(ERad) - e)
	var yv: float = a * sqrt(1 - e*e) * sin(ERad)
	#endregion
	
	#region Moon's distance and true anomaly
	var r: float = sqrt(xv * xv + yv * yv)
	var v: float =(atan2(yv, xv))
	#endregion
	
	#region Ecliptic
	var xeclip: float = r * (cos(NRad) * cos(v+wRad) - sin(NRad) * sin(v+wRad) * cos(iRad))
	var yeclip: float = r * (sin(NRad) * cos(v+wRad) + cos(NRad) * sin(v+wRad) * cos(iRad))
	var zeclip: float = r * sin(v+wRad) * sin(iRad)
	
	var long: float = atan2(yeclip, xeclip)
	var lat: float = atan2(zeclip, sqrt(xeclip * xeclip + yeclip * yeclip))
	var rs: float = sqrt(xeclip * xeclip + yeclip * yeclip + zeclip * zeclip)
	#endregion
   
	#region Perturbations
	var Ls: float = _mean_sun_longitude # Sun's  mean longitude
	var Lm: float = rev(N + w + M) # Moon's mean longitude
	var Ms: float = 356.0470 + 0.9856002585 * timeScale #Sun's  mean anomaly
	var Mm: float = M # Moon's mean anomaly
	var D: float = rev(Lm - Ls) # Moon's mean elongation
	var F: float = rev(Lm - N) # Moon's argument of latitude
	
	var lonPerp: float = (
		-1.274 *  sin_deg(Mm - 2 * D)
		+ 0.658 * sin_deg(2 * D)
		- 0.186 * sin_deg(Ms)
		- 0.059 * sin_deg(2 * Mm - 2 * D)
		- 0.057 * sin_deg(Mm - 2 * D + Ms)
		+ 0.053 * sin_deg(Mm + 2 * D)
		+ 0.046 * sin_deg(2 * D - Ms)
		+ 0.041 * sin_deg(Mm - Ms)
		- 0.035 * sin_deg(D)
		- 0.031 * sin_deg(Mm + Ms)
		- 0.015 * sin_deg(2 * F - 2 * D)
		+ 0.011 * sin_deg(Mm - 4 * D)
	)
	var latPerp: float = (
		- 0.173 * sin_deg(F - 2 * D)
		- 0.055 * sin_deg(Mm - F - 2 * D)
		- 0.046 * sin_deg(Mm + F - 2 * D)
		+ 0.033 * sin_deg(F + 2 * D)
		+ 0.017 * sin_deg(2 * Mm + F)
	)
	var lunarDistPerp: float = -0.58 * cos_deg(Mm - 2 * D) - 0.46 * cos_deg(2 * D)
	
	long += deg_to_rad(lonPerp)
	lat += deg_to_rad(latPerp)
	rs += deg_to_rad(lunarDistPerp)
	#endregion
	
	#region Ascencion and declination
	xeclip = rs * cos(long) * cos(lat)
	yeclip = rs * sin(long) * cos(lat)
	zeclip = rs * sin(lat)
	
	var xequat: float = xeclip
	var yequat: float = yeclip * cos(oblectRad) - zeclip * sin(oblectRad)
	var zequat: float = yeclip * sin(oblectRad) + zeclip * cos(oblectRad)
	
	var RA: float = rad_to_deg(atan2(yequat, xequat));
	var Decl: float = atan2(zequat, sqrt(xequat * xequat + yequat * yequat))
	#endregion
	
	#region Sideral time and hour angle.
	var HA: float = _local_sideral_time - RA
	var HARad: float = deg_to_rad(HA) 
	#endregion
	
	#region Topocentric
	## TODO: Adding this causes a NAN error. 
	## Apparently this is not necessary, the correction in altitude is sufficient.
	## Altitude output =  -17.1320296390843
	#var gclat: float = latitude - 0.1924 * sin(2.0 * latitude_rad)
	#var gclatRad: float = deg_to_rad(gclat)
	#var rho: float = 0.99833 + 0.00167 * cos(2.0 * latitude_rad)
#
	#var mpar: float = rad_to_deg(asin(1.0 / 60.6779))
	#var topRA: float = (RA - mpar * cos(gclatRad) * sin(HARad) / cos(Decl));
	#
	#var g: float = rad_to_deg(atan(tan(gclatRad) / cos(HARad)))
	#var gRad: float = deg_to_rad(g)
	#
	#var topDecl = rad_to_deg(Decl) - mpar * rho * sin(gclatRad) * sin(gRad - Decl) / sin(gRad)
	#var topDeclRad = deg_to_rad(topDecl)
	#
	#var topHA: float = (_sideral_time*15) - topRA
	#var topHARad: float = deg_to_rad(topHA)
	#endregion
	
	#region Azimuth and Altitude
	var x: float = cos(HARad) * cos(Decl)
	var y: float = sin(HARad) * cos(Decl)
	var z: float = sin(Decl)

	var xhor = x * sin(latitude_rad) - z * cos(latitude_rad)
	var yhor = y
	var zhor = x * cos(latitude_rad) + z * sin(latitude_rad)
	
	var azimuth = rad_to_deg(atan2(yhor, xhor) + PI)
	var altitude = rad_to_deg(asin(zhor))
	
	# Added topocentric correction
	var mpar: float = rad_to_deg(asin(1.0 / 60.6779))
	var altTopoc: float = altitude - mpar * cos(deg_to_rad(altitude))
	
	# Without topocentric adjustment of RA and Decl: -16.2274406891687
	# Stellarium = -16
	_moon_altitude = altTopoc
	
	# Output =  101.785328899489
	# Stellarium = 101 
	_moon_azimuth = azimuth
	#endregion

#endregion
