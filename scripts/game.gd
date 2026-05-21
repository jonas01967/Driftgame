extends Node3D

@onready var car: VehicleBody3D = $Car
@onready var camera_rig = $Car/CameraRig
@onready var track: Node3D = $TrackGenerator
@onready var hud: CanvasLayer = $HUD
@onready var coin_spawner: Node3D = $CoinSpawner

const COIN_SCENE := preload("res://scenes/coin.tscn")

func _ready() -> void:
	var mode := GameManager.current_mode
	GameManager.start_game(mode)
	camera_rig.setup(car)
	track.setup(car)
	hud.setup(car, mode)
	_schedule_coin_spawning()

func _schedule_coin_spawning() -> void:
	if GameManager.current_mode != GameManager.GameMode.SCORE:
		return
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.timeout.connect(_spawn_coins)
	add_child(timer)
	timer.start()

func _spawn_coins() -> void:
	var ahead = track.get_road_direction_at(car.global_position)
	var spawn_pos = car.global_position + ahead * 40.0
	spawn_pos.y += 1.0
	var coin := COIN_SCENE.instantiate()
	coin.global_position = spawn_pos
	coin_spawner.add_child(coin)
