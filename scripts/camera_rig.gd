extends Node3D

@export var orbit_sensitivity: float = 0.3
@export var zoom_sensitivity: float = 1.0
@export var min_zoom: float = 3.0
@export var max_zoom: float = 18.0
@export var min_pitch: float = -20.0
@export var max_pitch: float = 60.0
@export var follow_speed: float = 6.0
@export var rotation_speed: float = 3.0
@export var drift_fov_boost: float = 15.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target: Node3D
var yaw: float = 0.0
var pitch: float = 20.0
var zoom: float = 8.0
var is_orbiting: bool = false
var base_fov: float = 75.0
var current_drift_angle: float = 0.0

var is_reversing: bool = false
var reverse_timer: float = 0.0
const REVERSE_DELAY: float = 0.5

func _ready() -> void:
	base_fov = camera.fov
	spring_arm.spring_length = zoom
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func setup(car: Node3D) -> void:
	target = car
	global_position = car.global_position
	yaw = rad_to_deg(-car.rotation.y)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		is_orbiting = true
		yaw -= event.relative.x * orbit_sensitivity
		pitch -= event.relative.y * orbit_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clamp(zoom - zoom_sensitivity, min_zoom, max_zoom)
			spring_arm.spring_length = zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clamp(zoom + zoom_sensitivity, min_zoom, max_zoom)
			spring_arm.spring_length = zoom
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			is_orbiting = false

func _physics_process(delta: float) -> void:
	if target == null:
		return

	# Position weich folgen
	global_position = global_position.lerp(target.global_position, follow_speed * delta)

	var speed = target.linear_velocity.length() * 3.6

	if is_orbiting:
		spring_arm.rotation_degrees.x = -pitch
		rotation_degrees.y = yaw
	else:
		if speed > 5.0:
			# Rückwärts erkennen
			var forward := -target.global_transform.basis.z
			var vel_dot := forward.dot(target.linear_velocity.normalized()) \
						   if target.linear_velocity.length() > 0.5 else 1.0

			if vel_dot < -0.3:
				reverse_timer += delta
				if reverse_timer > REVERSE_DELAY:
					is_reversing = true
			else:
				reverse_timer = 0.0
				is_reversing = false

			# Ziel-Yaw
			var target_yaw: float
			if is_reversing:
				target_yaw = rad_to_deg(-target.rotation.y) 
			else:
				target_yaw = rad_to_deg(-target.rotation.y)

			# Kürzesten Weg nehmen
			var diff := fmod(target_yaw - yaw + 540.0, 360.0) - 180.0

			# Deadzone + maximale Drehgeschwindigkeit pro Frame
			if abs(diff) > 2.0:
				yaw += diff * clamp(rotation_speed * delta, 0.0, 0.15)

		elif speed < 2.0:
			reverse_timer = 0.0
			is_reversing = false

		# Pitch sanft zurück zur Standardhöhe
		pitch = lerp(pitch, 20.0, 3.0 * delta)
		spring_arm.rotation_degrees.x = -pitch
		rotation_degrees.y = yaw

	# FOV Drift-Effekt
	var target_fov := base_fov + current_drift_angle * 0.3
	target_fov = clamp(target_fov, base_fov, base_fov + drift_fov_boost)
	camera.fov = lerp(camera.fov, target_fov, 10.0 * delta)

	# Kamera-Tilt beim Driften
	var target_tilt := -current_drift_angle * 0.02
	target_tilt = clamp(target_tilt, -3.0, 3.0)
	camera.rotation_degrees.z = lerp(camera.rotation_degrees.z, target_tilt, 6.0 * delta)

func set_drift_angle(angle: float) -> void:
	current_drift_angle = angle
