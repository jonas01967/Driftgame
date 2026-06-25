extends CanvasLayer

@onready var speed_label: Label = $MarginContainer/VBox/SpeedLabel
@onready var score_label: Label = $MarginContainer/VBox/ScoreLabel
@onready var time_label: Label = $MarginContainer/VBox/TimeLabel
@onready var drift_label: Label = $MarginContainer/VBox/DriftLabel
@onready var mode_label: Label = $MarginContainer/VBox/ModeLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var final_label: Label = $GameOverPanel/VBoxContainer/FinalLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $GameOverPanel/VBoxContainer/MainMenuButton

var car_ref: Node3D
var drift_timer: float = 0.0
var current_drift_score: int = 0

func _ready() -> void:
	GameManager.score_changed.connect(_on_score)
	GameManager.time_changed.connect(_on_time)
	GameManager.game_over.connect(_on_game_over)
	game_over_panel.visible = false
	drift_label.modulate.a = 0.0
	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	main_menu_button.pressed.connect(func(): get_tree().)

func setup(car: Node3D, mode: GameManager.GameMode) -> void:
	car_ref = car
	car.drifting.connect(_on_drift)
	car.drift_ended.connect(_on_drift_ended)
	_setup_mode(mode)

func _process(delta: float) -> void:
	if car_ref == null:
		return

	# Geschwindigkeit immer anzeigen
	var speed_kmh = car_ref.linear_velocity.length() * 3.6
	speed_label.text = "🚗 %d km/h" % int(speed_kmh)

	# Drift-Label ausblenden nach Timeout
	if drift_timer > 0.0:
		drift_timer -= delta
	else:
		drift_label.modulate.a = lerp(drift_label.modulate.a, 0.0, delta * 3.0)

func _setup_mode(mode: GameManager.GameMode) -> void:
	match mode:
		GameManager.GameMode.FREE:
			mode_label.text = "🕹 Freies Spiel"
			time_label.visible = false
			score_label.text = "Punkte: 0"
		GameManager.GameMode.TIMER:
			mode_label.text = "⏱ Timer"
			time_label.visible = true
			time_label.text = "Zeit: 2:00"
			score_label.text = "Punkte: 0"
		GameManager.GameMode.SCORE:
			mode_label.text = "🪙 Punkte"
			time_label.visible = false
			score_label.text = "Punkte: 0"

func _on_drift(angle: float) -> void:
	drift_label.text = "⚡ DRIFT  %.0f°" % angle
	drift_label.modulate.a = 1.0
	drift_timer = 1.0

func _on_drift_ended() -> void:
	drift_timer = 0.3

func _on_score(value: int) -> void:
	score_label.text = "Punkte: %d" % value
	# Kurze Animation bei Punkteänderung
	var tween := create_tween()
	tween.tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.08)

func _on_time(value: float) -> void:
	var minutes := int(value) / 60
	var seconds := int(value) % 60
	time_label.text = "⏱ %d:%02d" % [minutes, seconds]
	if value < 20.0:
		time_label.modulate = Color.RED
		# Blinken unter 10 Sekunden
		if value < 10.0:
			time_label.visible = int(value * 2) % 2 == 0
	else:
		time_label.modulate = Color.WHITE
		time_label.visible = true

func _on_game_over(final_score: int) -> void:
	var mode_text := ""
	match GameManager.current_mode:
		GameManager.GameMode.TIMER:
			mode_text = "Timer abgelaufen!"
		GameManager.GameMode.SCORE:
			mode_text = "Spiel beendet!"
		_:
			mode_text = "Game Over"
	final_label.text = "%s\nPunkte: %d" % [mode_text, final_score]
	game_over_panel.visible = true
