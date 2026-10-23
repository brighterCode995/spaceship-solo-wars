class_name FollowCamera
extends Camera3D
## Perspective chase camera, similar to EverSpace 2: sits behind and above the
## ship, lags slightly in turns and widens the field of view with speed.

@export var offset: Vector3 = Vector3(0.0, 2.8, 9.0)
@export var follow_speed: float = 7.0
@export var base_fov: float = 70.0
@export var speed_fov: float = 14.0

var target: PlayerShip


func _ready() -> void:
	near = 0.3
	far = 2500.0
	process_physics_priority = 10 ## run after the ship has moved
	current = true


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_transform * offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
	var forward := -target.global_transform.basis.z
	var look_point := target.global_position + forward * 30.0
	var up := Vector3.UP
	if (look_point - global_position).normalized().abs().y > 0.98:
		up = Vector3.RIGHT
	look_at(look_point, up)
	fov = lerpf(fov, base_fov + speed_fov * target.get_speed_ratio(), 1.0 - exp(-3.0 * delta))


## Snaps the camera behind the target (used at level start).
func snap_to_target() -> void:
	if target == null:
		return
	global_position = target.global_transform * offset
	look_at(target.global_position - target.global_transform.basis.z * 30.0, Vector3.UP)
