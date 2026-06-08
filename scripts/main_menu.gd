extends Control

const GAME_SCENE := "res://scenes/Game.tscn"

func _ready() -> void:
	$CenterContainer/VBox/FreeBtn.pressed.connect(
		func(): _start(GameManager.GameMode.FREE))
	$CenterContainer/VBox/TimerBtn.pressed.connect(
		func(): _start(GameManager.GameMode.TIMER))
	$CenterContainer/VBox/ScoreBtn.pressed.connect(
		func(): _start(GameManager.GameMode.SCORE))
	_animate_title()

func _start(mode: GameManager.GameMode) -> void:
	GameManager.current_mode = mode
	get_tree().change_scene_to_file(GAME_SCENE)

func _animate_title() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property($TitelLabel, "modulate:v", 0.6, 1.0)
	tween.tween_property($TitelLabel, "modulate:v", 1.0, 1.0)
