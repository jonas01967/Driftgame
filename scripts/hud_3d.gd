extends CanvasLayer

@onready var speed_label: Label = $Margin/VBox/SpeedLabel
@onready var score_label: Label = $Margin/VBox/ScoreLabel
@onready var time_label: Label = $Margin/VBox/TimeLabel
@onready var drift_bar: ProgressBar = $Margin/VBox/DriftBar
@onready var drift_label: Label = $Margin/VBox/DriftLabel
@onready var mode_label: Label = $Margin/VBox/ModeLabel
@onready var crosshair: Control = $Crosshair
@onready var game_over_panel: Panel = $GameOverPanel

var car_ref: Node3D
var drift_timer: float = 0.0

func _ready() -> void:
	GameManager.score_changed.connect(_on_score)
	GameManager.time_changed.connect(_on_time)
	GameManager.game_over.connect(_on_game_over)
	game_over_panel.visible = false
	drift_bar.value = 0

func setup(car: Node3D, mode: GameManager.GameMode) -> void:
	car_ref = car
	car.drifting.connect(_on_drift)
	car.drift_ended.connect(_on_drift_ended)
	_setup_mode(mode)

func _process(delta: float) -> void:
	if car_ref == null:
		return
	var speed_kmh := car_ref.linear_velocity.length() * 3.6
	speed_label.text = "%d km/h" % int(speed_kmh)
	
	# Drift-Bar ausblenden
	if drift_timer > 0.0:
		drift_timer -= delta
	else:
		drift_bar.value = lerp(drift_bar.value, 0.0, delta * 4.0)

func _setup_mode(mode: GameManager.GameMode) -> void:
	match mode:
		GameManager.GameMode.FREE:
			mode_label.text = "Freies Spiel"
			time_label.visible = false
		GameManager.GameMode.TIMER:
			mode_label.text = "Timer"
		GameManager.GameMode.SCORE:
			mode_label.text = "Punkte"
			time_label.visible = false

func _on_drift(angle: float) -> void:
	drift_bar.value = clamp(angle / 60.0 * 100.0, 0.0, 100.0)
	drift_label.text = "DRIFT  %.0f°" % angle
	drift_timer = 0.8

func _on_drift_ended() -> void:
	drift_timer = 0.0

func _on_score(value: int) -> void:
	score_label.text = "Punkte: %d" % value

func _on_time(value: float) -> void:
	time_label.text = "Zeit: %.1f" % value
	time_label.modulate = Color.RED if value < 10.0 else Color.WHITE

func _on_game_over(final_score: int) -> void:
	game_over_panel.visible = true
	game_over_panel.get_node("VBox/FinalLabel").text = "Endergebnis: %d" % final_score
