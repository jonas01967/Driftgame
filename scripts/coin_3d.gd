extends Area3D

@export var value: int = 10
@export var spin_speed: float = 90.0
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.3

var _base_y: float
var _time: float = 0.0

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	rotation_degrees.y += spin_speed * delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.collect_coin(value)
		queue_free()
