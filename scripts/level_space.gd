class_name LevelSpace
extends LevelBase
## Level 1 - "Asteroid Belt": a dense asteroid field in deep space.

const SKY_SHADER_CODE := """
shader_type sky;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 cell = floor(dir * 180.0);
	float star = smoothstep(0.996, 1.0, hash31(cell));
	float tint = hash31(cell + 7.7);
	vec3 star_color = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.7), tint);
	float nebula = 0.5 + 0.5 * sin(dir.x * 3.0 + sin(dir.y * 4.0) * 2.0 + dir.z * 2.0);
	vec3 color = vec3(0.01, 0.01, 0.03) + vec3(0.05, 0.015, 0.08) * nebula * nebula;
	COLOR = color + star * star_color * 1.5;
}
"""

const ASTEROID_MODELS: Array[String] = [
	"res://assets/environment/Rock_Large_1.gltf",
	"res://assets/environment/Rock_Large_2.gltf",
	"res://assets/environment/Rock_Large_3.gltf",
	"res://assets/environment/Rock_1.gltf",
	"res://assets/environment/Rock_2.gltf",
	"res://assets/environment/Rock_3.gltf",
	"res://assets/environment/Rock_4.gltf",
]

const PLANET_MODELS: Array[String] = [
	"res://assets/environment/Planet_1.gltf",
	"res://assets/environment/Planet_2.gltf",
	"res://assets/environment/Planet_4.gltf",
	"res://assets/environment/Planet_7.gltf",
]

const ASTEROID_COUNT := 30


func _configure() -> void:
	volume_center = Vector3.ZERO
	player_start = Vector3(0, 0, 165)
	goal_position = Vector3(0, 0, -165)
	enemy_count = 5
	enemy_definition = GameData.ENEMY_SPACE
	dust_color = Color(0.75, 0.85, 1.0)
	rng.seed = 20260101


func _get_enemy_region() -> AABB:
	return AABB(Vector3(-130, -90, -110), Vector3(260, 180, 200))


func _build_environment() -> void:
	var shader := Shader.new()
	shader.code = SKY_SHADER_CODE
	var sky_material := ShaderMaterial.new()
	sky_material.shader = shader
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.45, 0.7)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 0.8
	make_world_environment(environment)

	make_sun(Vector3(-30, -35, 0), Color(1.0, 0.92, 0.8), 1.5, false)
	make_sun(Vector3(40, 140, 0), Color(0.4, 0.5, 1.0), 0.35, false)


func _build_world() -> void:
	# Distant planets (visual only) give the level its identity.
	var planet_spots: Array[Vector3] = [
		Vector3(-420, 160, -520),
		Vector3(480, -180, -380),
		Vector3(150, 330, -900),
		Vector3(-520, -250, 150),
	]
	for i in planet_spots.size():
		add_decor(PLANET_MODELS[i % PLANET_MODELS.size()], planet_spots[i], rng.randf_range(260.0, 420.0), rng.randf() * TAU)

	# Asteroid field (solid: collision + navigation voxelization).
	var region := AABB(Vector3(-170, -140, -150), Vector3(340, 280, 300))
	var placed: Array[Vector3] = []
	for i in ASTEROID_COUNT:
		var size := rng.randf_range(10.0, 28.0)
		var spot := find_free_position(region, size * 0.6, placed)
		placed.append(spot)
		var model_path := ASTEROID_MODELS[rng.randi() % ASTEROID_MODELS.size()]
		add_obstacle(model_path, spot, size, ColliderKind.SPHERE, false, false, rng.randf() * TAU)
