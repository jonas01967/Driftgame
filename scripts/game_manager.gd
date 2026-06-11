extends Node

enum GameMode { FREE, TIMER, SCORE }

signal score_changed(value: int)
signal time_changed(value: float)
signal game_over(final_score: int)

var current_mode: GameMode = GameMode.FREE
var score: int = 0
var time_left: float = 120.0
var is_running: bool = false
var drift_score_accum: float = 0.0

const TIMER_DURATION: float = 120.0
const DRIFT_SCORE_RATE: float = 8.0

func start_game(mode: GameMode) -> void:
	current_mode = mode
	score = 0
	drift_score_accum = 0.0
	time_left = TIMER_DURATION
	is_running = true
	score_changed.emit(score)
	time_changed.emit(time_left)

func _process(delta: float) -> void:
	if not is_running:
		return
	if current_mode == GameMode.TIMER:
		time_left -= delta
		time_changed.emit(time_left)
		if time_left <= 0.0:
			time_left = 0.0
			end_game()

func add_drift_score(drift_angle: float, delta: float) -> void:
	if not is_running:
		return
	# Punkte in ALLEN Modi beim Driften
	drift_score_accum += drift_angle * DRIFT_SCORE_RATE * delta
	var points := int(drift_score_accum)
	if points > 0:
		drift_score_accum -= points
		score += points
		score_changed.emit(score)

func collect_coin(value: int) -> void:
	if not is_running:
		return
	# Münzen nur im SCORE-Modus
	if current_mode != GameMode.SCORE:
		return
	score += value
	score_changed.emit(score)

func end_game() -> void:
	is_running = false
	game_over.emit(score)
