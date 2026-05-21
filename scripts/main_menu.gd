extends Control

@onready var free_btn: Button = $CenterContainer/VBox/FreePlayBtn
@onready var timer_btn: Button = $CenterContainer/VBox/TimerBtn
@onready var score_btn: Button = $CenterContainer/VBox/ScoreBtn
@onready var title_label: Label = $TitleLabel

const GAME_SCENE := "res://scenes/Game.tscn"

func _ready() -> void:
	free_btn.pressed.connect(func(): _start(GameManager.GameMode.FREE))
	timer_btn.pressed.connect(func(): _start(GameManager.GameMode.TIMER))
	score_btn.pressed.connect(func(): _start(GameManager.GameMode.SCORE))
	_animate_title()

func _start(mode: GameManager.GameMode) -> void:
	GameManager.current_mode = mode
	get_tree().change_scene_to_file(GAME_SCENE)

func _animate_title() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(title_label, "modulate:v", 0.7, 0.8)
	tween.tween_property(title_label, "modulate:v", 1.0, 0.8)
