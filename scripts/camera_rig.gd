extends Node3D

# Orbit-Einstellungen
@export var orbit_sensitivity: float = 0.3
@export var zoom_sensitivity: float = 1.0
@export var min_zoom: float = 3.0
@export var max_zoom: float = 18.0
@export var min_pitch: float = -20.0
@export var max_pitch: float = 60.0

# Rücklauf (Auto-Reset hinter das Auto)
@export var auto_return_delay: float = 2.0
@export var auto_return_speed: float = 4.0
@export var follow_speed: float = 8.0

# Drift-Effekte
@export var drift_fov_boost: float = 15.0
@export var drift_tilt_strength: float = 3.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target: Node3D
var yaw: float = 0.0
var pitch: float = 20.0
var zoom: float = 8.0
var auto_return_timer: float = 0.0
var is_orbiting: bool = false
var base_fov: float = 75.0
var current_drift_angle: float = 0.0

func _ready() -> void:
	base_fov = camera.fov
	spring_arm.spring_length = zoom
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func setup(car: Node3D) -> void:
	target = car
	global_position = car.global_position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		is_orbiting = true
		auto_return_timer = auto_return_delay
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
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not event.pressed:
				is_orbiting = false

	if event.is_action_pressed("ui_cancel"):
		var mode := Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
					else Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(mode)

func _physics_process(delta: float) -> void:
	if target == null:
		return

	# Position weich zum Auto interpolieren
	global_position = global_position.lerp(target.global_position, follow_speed * delta)

	# Auto-Rücklauf: Kamera dreht sich hinter das Auto
	if not is_orbiting:
		auto_return_timer -= delta
		if auto_return_timer <= 0.0:
			var target_yaw := rad_to_deg(-target.rotation.y)
			var diff := fmod(target_yaw - yaw + 540.0, 360.0) - 180.0
			yaw += diff * auto_return_speed * delta

	# Rotation anwenden
	rotation_degrees.y = yaw
	spring_arm.rotation_degrees.x = -pitch

	# Drift-FOV-Effekt
	var target_fov := base_fov + current_drift_angle * 0.3
	target_fov = clamp(target_fov, base_fov, base_fov + drift_fov_boost)
	camera.fov = lerp(camera.fov, target_fov, 10.0 * delta)

	# Kamera-Tilt beim Driften
	var target_tilt := -current_drift_angle * drift_tilt_strength * 0.01
	target_tilt = clamp(target_tilt, -drift_tilt_strength, drift_tilt_strength)
	camera.rotation_degrees.z = lerp(camera.rotation_degrees.z, target_tilt, 6.0 * delta)

func set_drift_angle(angle: float) -> void:
	current_drift_angle = angle
