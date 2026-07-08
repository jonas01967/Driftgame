extends Node3D

@export var spawn_distance_ahead: float = 200.0
@export var spawn_distance_behind: float = 160.0
@export var side_offset_min: float = 8.0
@export var side_offset_max: float = 22.0

var car_ref: Node3D
var track_ref: Node3D
var spawned_objects: Array[Dictionary] = []
var last_spawn_pos: Vector3 = Vector3.ZERO

const HOUSE_MEDIUM = preload("res://assets/models/house_medium.glb")
const HOUSE_TALL   = preload("res://assets/models/house_tall.glb")
const HOUSE_GARAGE = preload("res://assets/models/house_garage.glb")
const TREE_1       = preload("res://assets/models/tree_1.glb")
const TREE_2       = preload("res://assets/models/tree_2.glb")
const TREE_3       = preload("res://assets/models/tree_3.glb")
const GRASS        = preload("res://assets/models/grass.glb")

var house_scenes: Array = []
var tree_scenes: Array = []

func _ready() -> void:
	house_scenes = [HOUSE_MEDIUM, HOUSE_TALL, HOUSE_GARAGE]
	tree_scenes  = [TREE_1, TREE_2,]

func setup(car: Node3D, track: Node3D) -> void:
	car_ref        = car
	track_ref      = track
	last_spawn_pos = car.global_position

func _process(_delta: float) -> void:
	if car_ref == null or track_ref == null:
		return
	_recycle_old()
	_spawn_ahead()

func _spawn_ahead() -> void:
	if car_ref.global_position.distance_to(last_spawn_pos) < 18.0:
		return

	var road_dir  = track_ref.get_road_direction_at(car_ref.global_position)
	var ahead_pos = car_ref.global_position + road_dir * spawn_distance_ahead
	var perp      = road_dir.rotated(Vector3.UP, PI * 0.5)

	for side in [-1, 1]:
		# Haus
		if randf() > 0.35:
			var h_offset := randf_range(side_offset_min + 4.0, side_offset_max)
			var h_pos    = ahead_pos + perp * side * h_offset
			h_pos.y = 0.0
			_spawn_object(house_scenes[randi() % 3], h_pos, road_dir, true, true)

		# Bäume
		var tree_count := randi_range(2, 4)
		for i in range(tree_count):
			var t        := randf_range(0.1, 0.9)
			var t_pos    := car_ref.global_position.lerp(ahead_pos, t)
			var t_offset := randf_range(side_offset_min, side_offset_max + 6.0)
			t_pos += perp * side * t_offset
			t_pos.y = 0.0
			_spawn_object(tree_scenes[randi() % 2], t_pos, road_dir, false, true)

		# Gras — kein Schatten, keine Kollision nötig
		for i in range(4):
			var g_offset := randf_range(side_offset_min - 2.0, side_offset_max + 10.0)
			var g_fwd    := randf_range(-20.0, 20.0)
			var g_pos    = ahead_pos + road_dir * g_fwd + perp * side * g_offset
			g_pos.y = 0.0
			_spawn_object(GRASS, g_pos, road_dir, false, false)

	last_spawn_pos = car_ref.global_position

func _spawn_object(scene: PackedScene, pos: Vector3, road_dir: Vector3, face_road: bool, with_collision: bool) -> void:
	var instance := scene.instantiate()
	instance.position = pos

	if face_road:
		instance.rotation.y = atan2(road_dir.x, road_dir.z) + randf_range(-0.15, 0.15)
	else:
		instance.rotation.y = randf_range(0.0, TAU)

	add_child(instance)

	# Schatten bei allen MeshInstance3D deaktivieren
	_disable_shadows(instance)

	# Kollision automatisch aus Mesh generieren
	if with_collision:
		_add_collision_from_mesh(instance)

	spawned_objects.append({"node": instance, "pos": pos})

func _disable_shadows(node: Node) -> void:
	# Rekursiv alle MeshInstance3D finden und Schatten aus
	if node is MeshInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)

func _add_collision_from_mesh(node: Node) -> void:
	# Rekursiv alle MeshInstance3D finden und Kollision generieren
	if node is MeshInstance3D and node.mesh != null:
		var static_body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		# Vereinfachte Box-Kollision aus AABB des Mesh
		var aabb = node.mesh.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = aabb.size * node.get_parent().scale
		col.position = aabb.get_center()
		col.shape = shape
		static_body.add_child(col)
		node.add_child(static_body)
	for child in node.get_children():
		_add_collision_from_mesh(child)

func _recycle_old() -> void:
	var i := 0
	while i < spawned_objects.size():
		var obj := spawned_objects[i]
		if car_ref.global_position.distance_to(obj["pos"]) > spawn_distance_behind + 60.0:
			obj["node"].queue_free()
			spawned_objects.remove_at(i)
		else:
			i += 1
