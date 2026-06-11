extends Node3D

@export var segment_length: float = 40.0
@export var road_width: float = 150.0
@export var curve_strength: float = 10.0
@export var segments_visible: int = 20

var segments: Array[Dictionary] = []
var last_pos: Vector3 = Vector3.ZERO
var last_dir: Vector3 = Vector3(0, 0, -1)
var car_ref: Node3D

func _ready() -> void:
	for i in range(segments_visible + 40):
		_spawn_segment()

func setup(car: Node3D) -> void:
	car_ref = car

func _process(_delta: float) -> void:
	if car_ref == null:
		return
	_recycle_behind()
	_ensure_ahead()

func _spawn_segment() -> void:
	var curve := randf_range(-curve_strength, curve_strength)
	var new_dir := last_dir.rotated(Vector3.UP, deg_to_rad(curve)).normalized()

	var start := last_pos
	var end_pos := start + new_dir * (segment_length / 2)
	var center := start + new_dir * (segment_length * 0.5)

	var body := StaticBody3D.new()
	body.position = center

	var angle := atan2(new_dir.x, new_dir.z)
	body.rotation.y = angle

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(road_width, 0.3, segment_length)
	col.shape = shape
	body.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(road_width, 0.3, segment_length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)

	add_child(body)

	segments.append({
		"node": body,
		"start": start,
		"end": end_pos,
		"direction": new_dir,
	})

	last_pos = end_pos
	last_dir = new_dir

func _recycle_behind() -> void:
	if segments.is_empty() or car_ref == null:
		return
	if car_ref.global_position.distance_to(segments[0]["start"]) > segment_length * 6:
		segments[0]["node"].queue_free()
		segments.pop_front()

func _ensure_ahead() -> void:
	while segments.size() < segments_visible:
		_spawn_segment()

func get_road_direction_at(pos: Vector3) -> Vector3:
	var best := Vector3(0, 0, -1)
	var best_dist := INF
	for seg in segments:
		var d := pos.distance_to(seg["start"])
		if d < best_dist:
			best_dist = d
			best = seg["direction"]
	return best
