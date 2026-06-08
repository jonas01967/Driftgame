extends Node3D

@onready var car: VehicleBody3D = $Car
@onready var camera_rig = $Car/CameraRig
@onready var track: Node3D = $TrackGenerator
@onready var hud: CanvasLayer = $HUD
@onready var coin_spawner: Node3D = $CoinSpawner

const COIN_SCENE := preload("res://scenes/Coin3D.tscn")

func _ready() -> void:
	var mode = GameManager.current_mode
	GameManager.start_game(mode)
	camera_rig.setup(car)
	car.camera_rig = camera_rig
	track.setup(car)
	hud.setup(car, mode)

	# Münz-Spawner nur im Score-Modus
	if mode == GameManager.GameMode.SCORE:
		_start_coin_spawner()

func _start_coin_spawner() -> void:
	# Sofort erste Münzen spawnen
	for i in range(3):
		await get_tree().create_timer(float(i) * 1.5).timeout
		_spawn_coin()

	# Danach regelmäßig
	var timer := Timer.new()
	timer.wait_time = 4.0
	timer.timeout.connect(_spawn_coin)
	add_child(timer)
	timer.start()

func _spawn_coin() -> void:
	if not GameManager.is_running:
		return
	var ahead = track.get_road_direction_at(car.global_position)
	# Zufällig links/rechts versetzt auf der Straße
	var offset := randf_range(-3.0, 3.0)
	var perp = ahead.rotated(Vector3.UP, PI * 0.5) * offset
	var spawn_pos = car.global_position + ahead * randf_range(30.0, 50.0) + perp
	spawn_pos.y = 1.0
	var coin := COIN_SCENE.instantiate()
	coin.global_position = spawn_pos
	coin_spawner.add_child(coin)
