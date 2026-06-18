extends VehicleBody3D

signal drifting(angle: float)
signal drift_ended

@export var engine_force_value: float = 6000.0
@export var reverse_force_multiplier: float = 1.0
@export var brake_value: float = 30.0
@export var max_steer: float = 0.28
@export var steer_speed: float = 4.0
@export var drift_friction: float = 0.9
@export var normal_friction: float = 12.0
@export var max_speed_kmh: float = 250.0
@export var fall_threshold: float = -5.0
@export var respawn_height: float = 1.5

@onready var wheel_fl: VehicleWheel3D = $WheelFL
@onready var wheel_fr: VehicleWheel3D = $WheelFR
@onready var wheel_rl: VehicleWheel3D = $WheelRL
@onready var wheel_rr: VehicleWheel3D = $WheelRR
@onready var smoke_rl: GPUParticles3D = $WheelRL/Smoke
@onready var smoke_rr: GPUParticles3D = $WheelRR/Smoke

var steer_target: float = 0.0
var steer_input: float = 0.0
var is_drifting: bool = false
var drift_angle: float = 0.0
var handbrake: bool = false
var camera_rig: Node3D

var last_safe_position: Vector3 = Vector3.ZERO
var last_safe_rotation: Vector3 = Vector3.ZERO
var safe_position_timer: float = 0.0
var is_respawning: bool = false

var current_speed_kmh: float = 0.0

# Rückwärts-Status — wird auch von Kamera gelesen
var is_reversing: bool = false
var reverse_intent: bool = false  # S gedrückt
var moving_backward: bool = false # bewegt sich tatsächlich rückwärts

func _ready() -> void:
	mass = 250.0
	linear_damp = 0.15
	angular_damp = 10.0
	gravity_scale = 2.5
	_setup_wheels()
	last_safe_position = global_position
	last_safe_rotation = rotation_degrees

func _setup_wheels() -> void:
	for wheel in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		wheel.wheel_radius = 0.35
		wheel.wheel_rest_length = 0.15
		wheel.suspension_stiffness = 80.0
		wheel.suspension_max_force = 12000.0
		wheel.damping_compression = 0.5
		wheel.damping_relaxation = 0.6

	for wheel in [wheel_fl, wheel_fr]:
		wheel.wheel_friction_slip = 2.0

	for wheel in [wheel_rl, wheel_rr]:
		wheel.wheel_friction_slip = normal_friction

func _physics_process(delta: float) -> void:
	current_speed_kmh = linear_velocity.length() * 3.6
	_detect_direction()
	_handle_input(delta)
	_calculate_drift()
	_update_effects()
	_update_safe_position(delta)
	_check_respawn()

func _detect_direction() -> void:
	# Erkennt ob Auto sich tatsächlich rückwärts bewegt
	if linear_velocity.length() > 0.5:
		var forward := -global_transform.basis.z
		var vel_dot := forward.dot(linear_velocity.normalized())
		moving_backward = vel_dot < -0.2
	else:
		moving_backward = false

	is_reversing = moving_backward

func _handle_input(delta: float) -> void:
	if is_respawning:
		engine_force = 0.0
		brake = 500.0
		return

	var throttle    := Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	steer_input = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	handbrake = Input.is_action_pressed("handbrake")
	reverse_intent = throttle < 0.0

	var speed_ratio = clamp(current_speed_kmh / max_speed_kmh, 0.0, 1.0)

	# ── Motor ──
	if throttle > 0.0:
		# Vorwärts
		if current_speed_kmh > max_speed_kmh:
			engine_force = 0.0
		else:
			var torque_curve = 1.0 - speed_ratio * 0.6
			engine_force = engine_force_value * throttle * torque_curve

	elif throttle < 0.0:
		if not moving_backward and current_speed_kmh > 2.0:
			# Noch vorwärts unterwegs — bremsen
			engine_force = 0.0
			brake = brake_value * (0.3 + speed_ratio * 0.7)
		else:
			# Steht oder fährt bereits rückwärts — rückwärts fadhren
			engine_force = engine_force_value * throttle * reverse_force_multiplier
			brake = 0.0

	else:
		# Kein Gas — Motorbremse
		engine_force = 0.0
		if current_speed_kmh > 5.0:
			engine_force = -engine_force_value * 0.05 * speed_ratio

	# ── Handbremse ──
	if handbrake:
		var dynamic_brake = brake_value * (0.2 + speed_ratio * 0.8)
		if throttle > 0.0:
			engine_force *= 0.35
			dynamic_brake = brake_value * (0.55 + speed_ratio * 0.45)
		brake = dynamic_brake

	# Keine Bremse wenn Gas vorwärts und ohne Handbremse
	if throttle > 0.0 and not handbrake:
		brake = 0.0

	# ── Lenkung ──
	var steer_factor   = 1.0 - speed_ratio * 0.55
	var steer_response = steer_speed * (0.7 + speed_ratio * 0.6)

	# Lenkung umkehren beim Rückwärtsfahren
	var steer_dir := -1.0 if moving_backward else 1.0
	steer_target = steer_input * max_steer * steer_factor * steer_dir
	steering = lerp(steering, steer_target, steer_response * delta)

	if steer_input == 0.0:
		steering = lerp(steering, 0.0, steer_speed * 2.0 * delta)

	# ── Grip ──
	var speed_grip_reduction = 1.0 - speed_ratio * 0.15
	var grip := drift_friction if handbrake else normal_friction
	wheel_rl.wheel_friction_slip = grip * speed_grip_reduction
	wheel_rr.wheel_friction_slip = grip * speed_grip_reduction

	# ── Gegenlenken beim Drift ──
	if is_drifting and steer_input != 0.0:
		steering = lerp(steering, steer_target * 1.15, steer_speed * delta)

	# ── Stabilität ──
	if current_speed_kmh < 3.0:
		angular_velocity = angular_velocity.lerp(Vector3.ZERO, 0.3)

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

	var forward  := -global_transform.basis.z
	var vel_norm := linear_velocity.normalized()
	drift_angle  = rad_to_deg(acos(clamp(forward.dot(vel_norm), -1.0, 1.0)))

	var was_drifting := is_drifting
	is_drifting = drift_angle > 12.0 and (handbrake or abs(steer_input) > 0.2) and not moving_backward

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

func _update_safe_position(delta: float) -> void:
	if is_respawning:
		return
	safe_position_timer += delta
	if safe_position_timer >= 2.5:
		safe_position_timer = 0.0
		if global_position.y > -1.0 and global_position.y < 3.0:
			last_safe_position = global_position
			last_safe_rotation = rotation_degrees

func _check_respawn() -> void:
	if is_respawning:
		return
	var up_dot := global_transform.basis.y.dot(Vector3.UP)
	if global_position.y < fall_threshold or up_dot < -0.3:
		_respawn()

func _respawn() -> void:
	if is_respawning:
		return
	is_respawning = true
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	engine_force     = 0.0
	brake            = 500.0
	await get_tree().create_timer(0.5).timeout
	global_position  = last_safe_position + Vector3(0, respawn_height, 0)
	rotation_degrees = Vector3(0, last_safe_rotation.y, 0)
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	brake            = 0.0
	is_respawning    = false
