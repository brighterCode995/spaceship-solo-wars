class_name LevelPlanet
extends LevelBase
## Level 2 - "Canyon Run": skim an alien planet surface between towering rocks.

const BIG_ROCKS: Array[String] = [
	"res://assets/environment/Rock_Large_1.gltf",
	"res://assets/environment/Rock_Large_2.gltf",
	"res://assets/environment/Rock_Large_3.gltf",
]

const TREES: Array[String] = [
	"res://assets/environment/Tree_Blob_1.gltf",
	"res://assets/environment/Tree_Blob_2.gltf",
	"res://assets/environment/Tree_Spiral_1.gltf",
	"res://assets/environment/Tree_Spiral_2.gltf",
	"res://assets/environment/Tree_Swirl_1.gltf",
	"res://assets/environment/Tree_Light_1.gltf",
	"res://assets/environment/Tree_Spikes_1.gltf",
]

const GROUND_PROPS: Array[String] = [
	"res://assets/environment/Bush_1.gltf",
	"res://assets/environment/Bush_2.gltf",
	"res://assets/environment/Grass_1.gltf",
	"res://assets/environment/Plant_1.gltf",
]

const BASE_MODEL := "res://assets/environment/Base_Large.gltf"
const DOME_MODEL := "res://assets/environment/GeodesicDome.gltf"


func _configure() -> void:
	volume_center = Vector3(0, 150, 0)
	player_start = Vector3(0, 55, 165)
	goal_position = Vector3(0, 45, -165)
	enemy_count = 5
	enemy_definition = GameData.ENEMY_PLANET
	floor_y = 7.0
	ceiling_y = 175.0
	dust_color = Color(1.0, 0.85, 0.6)
	rng.seed = 77031


func _get_enemy_region() -> AABB:
	return AABB(Vector3(-110, 25, -110), Vector3(220, 90, 200))


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.12, 0.45)
	sky_material.sky_horizon_color = Color(1.0, 0.55, 0.32)
	sky_material.ground_horizon_color = Color(1.0, 0.55, 0.32)
	sky_material.ground_bottom_color = Color(0.25, 0.12, 0.12)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.55, 0.6)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.95, 0.55, 0.4)
	environment.fog_density = 0.0028
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.1
	environment.glow_hdr_threshold = 0.85
	make_world_environment(environment)

	make_sun(Vector3(-28, 35, 0), Color(1.0, 0.8, 0.6), 1.6, true)


func _build_world() -> void:
	_build_ground()

	# Two walls of tall rocks form the canyon.
	var z := -150.0
	while z <= 150.0:
		for side in [-1.0, 1.0]:
			var x: float = side * rng.randf_range(85.0, 115.0)
			var path: String = BIG_ROCKS[rng.randi() % BIG_ROCKS.size()]
			add_obstacle(path, Vector3(x, 0, z + rng.randf_range(-6.0, 6.0)), rng.randf_range(45.0, 75.0), ColliderKind.BOX, true, true, rng.randf() * TAU)
		z += 36.0

	# A few boulders in the valley force the player to weave.
	for i in 9:
		var spot := Vector3(rng.randf_range(-60.0, 60.0), 0, rng.randf_range(-120.0, 110.0))
		if spot.distance_to(Vector3(0, 0, player_start.z)) < 40.0:
			continue
		var path: String = BIG_ROCKS[rng.randi() % BIG_ROCKS.size()]
		add_obstacle(path, spot, rng.randf_range(25.0, 45.0), ColliderKind.BOX, true, true, rng.randf() * TAU)

	# Alien trees (solid) and low vegetation (visual only).
	for i in 24:
		var spot := Vector3(rng.randf_range(-150.0, 150.0), 0, rng.randf_range(-150.0, 150.0))
		var path: String = TREES[rng.randi() % TREES.size()]
		add_obstacle(path, spot, rng.randf_range(14.0, 24.0), ColliderKind.CYLINDER, true, true, rng.randf() * TAU)
	for i in 70:
		var spot := Vector3(rng.randf_range(-190.0, 190.0), 0, rng.randf_range(-190.0, 190.0))
		var path: String = GROUND_PROPS[rng.randi() % GROUND_PROPS.size()]
		add_decor(path, spot, rng.randf_range(3.0, 6.0), rng.randf() * TAU, true)

	# Landmarks near the goal.
	add_obstacle(BASE_MODEL, Vector3(-55, 0, -150), 55.0, ColliderKind.BOX, false, true, 0.4)
	add_obstacle(DOME_MODEL, Vector3(60, 0, -135), 40.0, ColliderKind.SPHERE, false, true, 0.0)


func _build_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.16, 0.3, 0.2))
	ramp.set_color(1, Color(0.42, 0.5, 0.26))
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = ramp
	texture.seamless = true
	texture.width = 512
	texture.height = 512

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.uv1_scale = Vector3(60, 60, 1)
	material.roughness = 1.0

	var plane := PlaneMesh.new()
	plane.size = Vector2(5000, 5000)
	plane.material = material
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	add_child(ground)

	# Solid ground for collisions and navigation (top surface at y = 0).
	add_collision_box(Vector3(0, -2, 0), Vector3(level_size, 4, level_size))
