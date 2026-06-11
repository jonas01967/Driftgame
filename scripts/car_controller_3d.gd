extends VehicleBody3D

signal drifting(angle: float)
signal drift_ended

@export var engine_force_value: float = 4000.0
@export var brake_value: float = 20.0
@export var max_steer: float = 0.25
@export var steer_speed: float = 3.0
@export var drift_friction: float = 0.85
@export var normal_friction: float = 10.5
@export var max_speed_kmh: float = 250.0

@onready var wheel_fl: VehicleWheel3D = $WheelFL
@onready var wheel_fr: VehicleWheel3D = $WheelFR
@onready var wheel_rl: VehicleWheel3D = $WheelRL
@onready var wheel_rr: VehicleWheel3D = $WheelRR
@onready var smoke_rl: GPUParticles3D = $WheelRL/Smoke
@onready var smoke_rr: GPUParticles3D = $WheelRR/Smoke

var steer_target: float = 0.0
var is_drifting: bool = false
var drift_angle: float = 0.0
var handbrake: bool = false
var camera_rig: Node3D

func _ready() -> void:
	mass = 250.0
	linear_damp = 0.5
	angular_damp = 8.0
	_setup_wheels()

func _setup_wheels() -> void:
	for wheel in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		wheel.wheel_radius = 0.35
		wheel.wheel_rest_length = 0.2
		wheel.suspension_stiffness = 50.0
		wheel.suspension_max_force = 8000.0
		wheel.damping_compression = 0.4
		wheel.damping_relaxation = 0.5

	for wheel in [wheel_fl, wheel_fr]:
		wheel.wheel_friction_slip = 2.5

	for wheel in [wheel_rl, wheel_rr]:
		wheel.wheel_friction_slip = normal_friction

func _physics_process(delta: float) -> void:
	_handle_input(delta)
	_calculate_drift()
	_update_effects()

func _handle_input(delta: float) -> void:
	var throttle    := Input.get_axis("ui_down", "ui_up")
	var steer_input := Input.get_axis("ui_right", "ui_left")
	handbrake = Input.is_action_pressed("handbrake")

	var speed_kmh := linear_velocity.length() * 3.6

	# Motor
	if speed_kmh > max_speed_kmh:
		engine_force = 0.0
	else:
		engine_force = engine_force_value * throttle

	# Bremskraft je nach Geschwindigkeit
	var speed_ratio    = clamp(speed_kmh / max_speed_kmh, 0.0, 1.0)
	var dynamic_brake  = brake_value * (0.3 + speed_ratio * 0.7)

	if handbrake:
		brake = dynamic_brake * 0.4
	elif throttle < 0.0:
		brake = dynamic_brake
	else:
		brake = 0.0

	# Motorbremse beim Gasloslassen
	if throttle == 0.0 and not handbrake:
		engine_force = -engine_force_value * 0.08 * speed_ratio

	# Progressives Lenken
	var steer_factor = 1.0 - speed_ratio * 0.5
	steer_target = steer_input * max_steer * steer_factor
	steering = lerp(steering, steer_target, steer_speed * delta)

	# Grip
	var grip := drift_friction if handbrake else normal_friction
	wheel_rl.wheel_friction_slip = grip
	wheel_rr.wheel_friction_slip = grip

	# Gegenlenken beim Drift
	if is_drifting and steer_input != 0.0:
		steering = lerp(steering, steer_target * 1.1, steer_speed * 1.2 * delta)

func _calculate_drift() -> void:
	var speed := linear_velocity.length()
	if speed < 2.0:
		if is_drifting:
			drift_ended.emit()
		is_drifting = false
		drift_angle = 0.0
		if camera_rig:
			camera_rig.set_drift_angle(0.0)
		return

	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length() == 0.0:
		return
	forward = forward.normalized()

	var right := forward.cross(Vector3.UP)
	if right.length() == 0.0:
		return
	right = right.normalized()

	var vel_horiz := linear_velocity
	vel_horiz.y = 0.0
	if vel_horiz.length() == 0.0:
		if is_drifting:
			drift_ended.emit()
		is_drifting = false
		drift_angle = 0.0
		if camera_rig:
			camera_rig.set_drift_angle(0.0)
		return

	var longitudinal := forward.dot(vel_horiz)
	var lateral := right.dot(vel_horiz)
	drift_angle = rad_to_deg(abs(atan2(lateral, longitudinal)))

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
	var show_smoke := is_drifting or (handbrake and linear_velocity.length() > 3.0)
	if smoke_rl:
		smoke_rl.emitting = show_smoke
	if smoke_rr:
		smoke_rr.emitting = show_smoke
