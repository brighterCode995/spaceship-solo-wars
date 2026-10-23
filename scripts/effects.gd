class_name Effects
extends RefCounted
## Static helpers for glowing materials, CPU particle effects and model measuring.


static func glow_material(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func particle_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


## Bounding box of every mesh below [param root], in the root's local space.
static func get_model_aabb(root: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	for child in root.get_children():
		_collect_aabbs(child, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	var merged: AABB = boxes[0]
	for i in range(1, boxes.size()):
		merged = merged.merge(boxes[i])
	return merged


static func find_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		find_meshes(child, out)


static func spawn_explosion(parent: Node, position: Vector3, size: float = 1.0) -> void:
	var fire := _make_burst(Color(1.0, 0.85, 0.3), Color(1.0, 0.15, 0.0, 0.0), 60, 1.0, 14.0 * size, 0.7 * size)
	_launch(parent, fire, position, 1.0)
	var sparks := _make_burst(Color(1.0, 1.0, 0.9), Color(1.0, 0.6, 0.2, 0.0), 30, 0.8, 30.0 * size, 0.18 * size)
	_launch(parent, sparks, position, 0.8)


static func spawn_sparks(parent: Node, position: Vector3) -> void:
	var sparks := _make_burst(Color(1.0, 0.95, 0.6), Color(1.0, 0.4, 0.1, 0.0), 12, 0.4, 14.0, 0.16)
	_launch(parent, sparks, position, 0.4)


## Continuous engine flame. Particles stay in world space so they form a trail.
static func make_engine_trail(color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = 28
	particles.lifetime = 0.5
	particles.local_coords = false
	particles.direction = Vector3(0, 0, 1)
	particles.spread = 4.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 3.0
	particles.mesh = small_sphere(0.22)
	particles.color_ramp = fade_gradient(color, Color(color.r, color.g, color.b, 0.0))
	particles.scale_amount_curve = shrink_curve()
	return particles


## Drifting dust specks around the camera that give a strong sense of speed.
static func make_dust(color: Color, extents: Vector3, amount: int) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 3.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = extents
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 0.0
	particles.initial_velocity_max = 0.0
	particles.mesh = small_sphere(0.09)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.0))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.4, Color(color.r, color.g, color.b, 0.7))
	particles.color_ramp = gradient
	return particles


static func _collect_aabbs(node: Node, parent_xform: Transform3D, out: Array[AABB]) -> void:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			out.append(xform * mesh_instance.mesh.get_aabb())
	for child in node.get_children():
		_collect_aabbs(child, xform, out)


static func _make_burst(start: Color, end: Color, amount: int, lifetime: float, speed: float, radius: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = speed * 0.3
	particles.initial_velocity_max = speed
	particles.damping_min = speed * 0.4
	particles.damping_max = speed * 0.7
	particles.mesh = small_sphere(radius)
	particles.color_ramp = fade_gradient(start, end)
	particles.scale_amount_curve = shrink_curve()
	return particles


static func _launch(parent: Node, particles: CPUParticles3D, position: Vector3, life: float) -> void:
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	parent.get_tree().create_timer(life + 0.5).timeout.connect(particles.queue_free)


static func small_sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = particle_material()
	return mesh


static func fade_gradient(start: Color, end: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, start)
	gradient.set_color(1, end)
	return gradient


static func shrink_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.1))
	return curve
