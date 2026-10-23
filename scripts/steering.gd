class_name Steering
extends RefCounted
## Steering behaviours for the flying enemies.
##
## Every function returns a *desired velocity*; the enemy accelerates towards it.
## Behaviours follow the classic definitions from Craig Reynolds,
## "Steering Behaviors For Autonomous Characters" (1999), in 3D.
## Path following uses waypoints from the Godot Flight Navigation 3D plugin
## (RevolNoom, https://github.com/RevolNoom/godot_flight_navigation_3d).


## Seek: head straight for a point at full speed.
static func seek(position: Vector3, target: Vector3, max_speed: float) -> Vector3:
	return (target - position).normalized() * max_speed


## Arrive: like seek, but slows down inside [param slow_radius].
static func arrive(position: Vector3, target: Vector3, max_speed: float, slow_radius: float) -> Vector3:
	var to_target := target - position
	var distance := to_target.length()
	if distance < 0.01:
		return Vector3.ZERO
	var speed := max_speed * clampf(distance / slow_radius, 0.0, 1.0)
	return to_target / distance * speed


## Pursue: seek where a moving target is predicted to be.
static func pursue(position: Vector3, target_position: Vector3, target_velocity: Vector3, max_speed: float) -> Vector3:
	var distance := position.distance_to(target_position)
	var prediction_time := distance / maxf(max_speed, 0.01)
	var predicted := target_position + target_velocity * prediction_time * 0.5
	return seek(position, predicted, max_speed)


## Wander: moves a point around the surface of a sphere in front of the agent.
## Returns the new offset; combine it with the agent's forward direction.
static func wander_offset(offset: Vector3, jitter: float, radius: float, delta: float) -> Vector3:
	var random_push := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	var new_offset := offset + random_push * jitter * delta
	if new_offset.length() < 0.001:
		new_offset = Vector3.FORWARD
	return new_offset.normalized() * radius


## Obstacle avoidance: casts a fan of rays ahead and returns a push-away vector
## (length 0..~2) made from the surface normals that were hit.
static func avoid_obstacles(
	body: CollisionObject3D,
	forward: Vector3,
	look_ahead: float,
	collision_mask: int
) -> Vector3:
	var space := body.get_world_3d().direct_space_state
	var origin := body.global_position
	var right := forward.cross(Vector3.UP)
	if right.length() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(forward).normalized()
	var directions: Array[Vector3] = [
		forward,
		(forward + right * 0.35).normalized(),
		(forward - right * 0.35).normalized(),
		(forward + up * 0.35).normalized(),
		(forward - up * 0.35).normalized(),
	]
	var push := Vector3.ZERO
	for direction: Vector3 in directions:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * look_ahead, collision_mask)
		query.exclude = [body.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_position: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		var strength := 1.0 - origin.distance_to(hit_position) / look_ahead
		push += normal * strength
	return push
