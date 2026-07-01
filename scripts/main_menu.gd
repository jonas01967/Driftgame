extends Control

const GAME_SCENE := "res://scenes/Game.tscn"

@onready var titel: Label = $CenterContainer/VBox/TitelLabel

func _ready() -> void:
	$CenterContainer/VBox/FreeBtn.pressed.connect(
		func(): _start(GameManager.GameMode.FREE))
	$CenterContainer/VBox/TimerBtn.pressed.connect(
		func(): _start(GameManager.GameMode.TIMER))
	$CenterContainer/VBox/ScoreBtn.pressed.connect(
		func(): _start(GameManager.GameMode.SCORE))
	_animate_title()
	_animate_buttons()

func _start(mode: GameManager.GameMode) -> void:
	GameManager.current_mode = mode
	get_tree().change_scene_to_file(GAME_SCENE)

func _animate_title() -> void:
	# Titel pulsiert
	var tween := create_tween().set_loops()
	tween.tween_property(titel, "modulate:v", 0.6, 1.2)
	tween.tween_property(titel, "modulate:v", 1.0, 1.2)

func _animate_buttons() -> void:
	# Buttons erscheinen nacheinander von unten
	var vbox := $CenterContainer/VBox
	for i in range(vbox.get_child_count()):
		var child := vbox.get_child(i)
		child.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.1 * i)
		tween.tween_property(child, "modulate:a", 1.0, 0.4)
