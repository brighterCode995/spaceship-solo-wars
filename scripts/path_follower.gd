class_name PathFollower
extends RefCounted
## Path following steering behaviour: walks through a list of waypoints.
## Waypoints come from FlightNavigation3D.find_path() (voxel centres).

var _path: PackedVector3Array = PackedVector3Array()
var _index: int = 0


func set_path(path: PackedVector3Array) -> void:
	_path = path
	_index = 0


func clear() -> void:
	_path = PackedVector3Array()
	_index = 0


func has_path() -> bool:
	return _index < _path.size()


## Desired velocity towards the current waypoint; advances when it is reached.
func get_desired_velocity(position: Vector3, max_speed: float, reach_radius: float) -> Vector3:
	while _index < _path.size() and position.distance_to(_path[_index]) < reach_radius:
		_index += 1
	if _index >= _path.size():
		return Vector3.ZERO
	return Steering.seek(position, _path[_index], max_speed)
