extends VehicleBody3D

signal drifting(angle: float)
signal drift_ended

@export var engine_force_value: float = 8000.0
@export var brake_value: float = 5.0
@export var max_steer: float = 0.4
@export var steer_speed: float = 5.0
@export var drift_friction: float = 0.6
@export var normal_friction: float = 0.9

@onready var wheel_fl: VehicleWheel3D = $WheelFL
@onready var wheel_fr: VehicleWheel3D = $WheelFR
@onready var wheel_rl: VehicleWheel3D = $WheelRL
@onready var wheel_rr: VehicleWheel3D = $WheelRR
@onready var smoke_rl: GPUParticles3D = $WheelRL/Smoke
@onready var smoke_rr: GPUParticles3D = $WheelRR/Smoke
@onready var camera_rig: Node3D  # wird von Game.gd gesetzt

var steer_target: float = 0.0
var is_drifting: bool = false
var drift_angle: float = 0.0
var handbrake: bool = false

func _physics_process(delta: float) -> void:
	print("throttle: ", Input.get_axis("ui_down", "ui_up"))
	_handle_input(delta)
	_calculate_drift()
	_update_effects()

func _handle_input(delta: float) -> void:
	var throttle := Input.get_axis("ui_up", "ui_down")
	var steer_input := Input.get_axis("ui_left", "ui_right")
	handbrake = Input.is_action_pressed("handbrake")

	# Motor
	engine_force = engine_force_value * throttle
	brake = brake_value if handbrake else 0.0

	# Lenkung
	steer_target = steer_input * max_steer
	steering = lerp(steering, steer_target, steer_speed * delta)

	# Grip / Drift
	var grip := drift_friction if handbrake else normal_friction
	wheel_rl.wheel_friction_slip = grip
	wheel_rr.wheel_friction_slip = grip

func _calculate_drift() -> void:
	var speed := linear_velocity.length()
	if speed < 2.0:
		is_drifting = false
		drift_angle = 0.0
		if camera_rig:
			camera_rig.set_drift_angle(0.0)
		return

	var forward := -global_transform.basis.z
	var vel_norm := linear_velocity.normalized()
	drift_angle = rad_to_deg(acos(clamp(forward.dot(vel_norm), -1.0, 1.0)))
	
	var was_drifting := is_drifting
	is_drifting = drift_angle > 12.0 and handbrake

	if is_drifting:
		drifting.emit(drift_angle)
		GameManager.add_drift_score(drift_angle, get_physics_process_delta_time())
	elif was_drifting:
		drift_ended.emit()

	if camera_rig:
		camera_rig.set_drift_angle(drift_angle if is_drifting else 0.0)

func _update_effects() -> void:
	var show_smoke := is_drifting
	smoke_rl.emitting = show_smoke
	smoke_rr.emitting = show_smoke
