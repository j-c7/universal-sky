@tool @icon("res://addons/universal-sky/assets/icons/godot/datetime.svg")
extends Node
class_name PlanetaryDateTime3D

const _MAX_TIMELINE_VALUE: int = 24.0
const _MIN_TIMELINE_VALUE: int = 0.0000

enum DateTimeProp{ TIMELINE = 0, DAY, MONTH, YEAR }
enum ProcessTimeMode{ Editor = 0, Runtime, Both, Off }

signal datetime_property_changed(param_name)

@export 
var system_sync: bool = false:
	get: return system_sync
	set(value):
		system_sync = value

@export 
var total_cycle_in_minutes: float = 15.0:
	get: return total_cycle_in_minutes
	set(value):
		total_cycle_in_minutes = value

@export
var process_time_mode:= ProcessTimeMode.Both:
	get: return process_time_mode
	set(value):
		process_time_mode = value

@export
var update_interval: float = 0.0:
	get: return update_interval
	set(value):
		update_interval = value

@export_range(0.0, 24.0)
var timeline: float = 7.0:
	get: return timeline
	set(value):
		while value > _MAX_TIMELINE_VALUE:
			value -= _MAX_TIMELINE_VALUE
			day += 1
		while value < _MIN_TIMELINE_VALUE:
			day -= 1
			value += _MAX_TIMELINE_VALUE
		timeline = value
		datetime_property_changed.emit(DateTimeProp.TIMELINE)

@export
var day: int = 12:
	get: return day
	set(value):
		while value > max_days_per_month:
			value -= max_days_per_month
			month += 1
		while value < 1:
			month -= 1
			value += max_days_per_month
		day = value
		datetime_property_changed.emit(DateTimeProp.DAY)

@export
var month: int = 2:
	get: return month
	set(value):
		while value > 12:
			value -= 12
			year += 1
		while value < 1:
			year -= 1
			value += 12
		month = value
		datetime_property_changed.emit(DateTimeProp.MONTH)

@export
var year: int = 2025:
	get: return year
	set(value):
		#year = max(0, value)
		year = value
		datetime_property_changed.emit(DateTimeProp.YEAR)

var _date_time_os: Dictionary

var _update_timer: float = 0.0

var _is_editor: bool: 
	get: return Engine.is_editor_hint()

var is_leap_year: bool:
	get: return (year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0)

var time_cycle_duration: float:
	get: return total_cycle_in_minutes * 60.0

var max_days_per_month: int:
	get:
		match month:
			1, 3, 5, 7, 8, 10, 12:
				return 31
			2:
				return 29 if is_leap_year else 28
		return 30

#region Godot Node Overrides
func _enter_tree() -> void:
	system_sync = system_sync
	total_cycle_in_minutes = total_cycle_in_minutes
	timeline = timeline
	day = day
	month = month
	year = year

func _process(delta: float) -> void:
	if _can_process():
		if update_interval > 0.000000:
			_update_timer += delta
		if _update_timer > update_interval or is_zero_approx(update_interval):
			if not system_sync:
				_time_process(delta)
			else:
				_get_date_time_os()
			_update_timer = 0.0
#endregion

#region Process Time
func _can_process() -> bool:
	match(process_time_mode):
		ProcessTimeMode.Editor:
			return true if _is_editor else false
		ProcessTimeMode.Runtime:
			return  true if not _is_editor else false
		ProcessTimeMode.Both:
			return true
	return false

func _time_process(p_delta: float) -> void:
	if not is_zero_approx(time_cycle_duration):
		timeline = timeline + p_delta / time_cycle_duration * 24.0

func _get_date_time_os() -> void:
	_date_time_os = Time.get_datetime_dict_from_system()
	set_time(_date_time_os.hour, _date_time_os.minute, _date_time_os.second)
	day = _date_time_os.day
	month = _date_time_os.month
	year = _date_time_os.year
#endregion

#region Set Time Values
func set_oclock(p_hour: int) -> void:
	timeline = float(p_hour)

func set_time(p_hour:int, p_minutes: int, p_seconds: int) -> void:
	timeline = float(p_hour) + float(p_hour) / 60.0 + float(p_hour) / 3600.0

func set_precise_time(p_hour: int, p_minutes: int, p_seconds: int, p_milliseconds: int) -> void: 
	timeline = float(p_hour) + float(p_minutes) / 60.0 + float(p_seconds) / 3600.0 +\
		float(p_milliseconds) / 3600000.0
#endregion
