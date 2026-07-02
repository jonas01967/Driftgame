extends Node3D

@onready var car: VehicleBody3D = $Car
@onready var camera_rig = $Car/CameraRig
@onready var track: Node3D = $TrackGenerator
@onready var hud: CanvasLayer = $HUD
@onready var coin_spawner: Node3D = $CoinSpawner
@onready var env_spawner: Node3D = $EnvironmentSpawner

const COIN_SCENE := preload("res://scenes/Coin3D.tscn")

func _ready() -> void:
	_setup_lighting()
	var mode := GameManager.current_mode
	GameManager.start_game(mode)
	camera_rig.setup(car)
	car.camera_rig = camera_rig
	track.setup(car)
	hud.setup(car, mode)
	env_spawner.setup(car, track)

	if mode == GameManager.GameMode.SCORE:
		_start_coin_spawner()

func _setup_lighting() -> void:
	# Vorhandene Lichter entfernen
	for child in get_children():
		if child is DirectionalLight3D:
			child.queue_free()
		if child is WorldEnvironment:
			child.queue_free()

	# 4 Lichter aus verschiedenen Winkeln
	var lights := [
		{"rot": Vector3(-45, 45, 0),   "energy": 1.0,  "shadow": true},
		{"rot": Vector3(-30, -135, 0), "energy": 0.45, "shadow": false},
		{"rot": Vector3(-20, 135, 0),  "energy": 0.35, "shadow": false},
		{"rot": Vector3(-25, -45, 0),  "energy": 0.35, "shadow": false},
	]

	for l in lights:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = l["rot"]
		light.light_energy = l["energy"]
		light.shadow_enabled = l["shadow"]
		light.light_color = Color(1.0, 0.97, 0.92)
		add_child(light)

	# Himmel und Ambiente
	var env_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.65, 0.7)
	environment.ambient_light_energy = 0.6
	environment.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.5, 0.8)
	sky_mat.sky_horizon_color = Color(0.7, 0.8, 0.9)
	sky_mat.ground_bottom_color = Color(0.2, 0.25, 0.2)
	sky_mat.ground_horizon_color = Color(0.5, 0.55, 0.45)
	sky.sky_material = sky_mat
	environment.sky = sky
	env_node.environment = environment
	add_child(env_node)

func _start_coin_spawner() -> void:
	# Erste Münzen sofort spawnen
	for i in range(3):
		await get_tree().create_timer(float(i) * 1.5).timeout
		_spawn_coin()

	# Danach regelmäßig alle 4 Sekunden
	var timer := Timer.new()
	timer.wait_time = 4.0
	timer.timeout.connect(_spawn_coin)
	add_child(timer)
	timer.start()

func _spawn_coin() -> void:
	if not GameManager.is_running:
		return
	var road_dir = track.get_road_direction_at(car.global_position)
	var perp = road_dir.rotated(Vector3.UP, PI * 0.5)
	var offset := randf_range(-3.0, 3.0)
	var spawn_pos = car.global_position + road_dir * randf_range(30.0, 50.0) + perp * offset
	spawn_pos.y = 1.0
	var coin := COIN_SCENE.instantiate()
	coin.global_position = spawn_pos
	coin_spawner.add_child(coin)

func _inpuwt(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_just_pressed("ui_cancel"):
		GameManager.is_running = false
		get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")
