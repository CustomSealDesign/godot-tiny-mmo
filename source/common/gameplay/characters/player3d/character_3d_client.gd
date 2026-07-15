@icon("res://assets/node_icons/blue/icon_character.png")
class_name Character3DClient
extends Node2D
## Client-only character root that keeps the server's Vector2 :position wire format
## on this Node2D while a CharacterBody3D child renders and moves in 3D.


signal display_name_changed(new_name: String)

enum Animations {
	IDLE,
	RUN,
	DEATH,
}

const BAR_COLOR_SELF: Color = Color(0.38, 0.82, 0.42)
const BAR_COLOR_ALLY: Color = Color(0.30, 0.62, 1.0)
const BAR_COLOR_NEUTRAL: Color = Color(0.82, 0.82, 0.86)
const BAR_COLOR_HOSTILE: Color = Color(0.86, 0.33, 0.28)

static var local_viewer_guild_id: int = 0
static var spar_ally_peers: Array = []
static var spar_opponent_peers: Array = []
static var group_peers: Array = []

var hand_type: Hand.Types

var skin_id: int:
	set = _set_skin_id

var display_name: String = "Unknown":
	set = _set_display_name

var anim: Animations = Animations.IDLE:
	set = _set_anim

var flipped: bool = false:
	set = _set_flip

var pivot: float = 0.0:
	set = _set_pivot

var ability_cooldowns: Dictionary = {}
var armed_shot: Dictionary = {}
var net_smooth_delay_ms: int = 100
var health_bar_auto_hide: bool = true
var is_dead: bool = false
var zone_flags: int = 0

var _net_smoother: NetMotionSmoother
var _last_health_seen: float = -1.0
var _hit_flash_tween: Tween
var _bar_value_tween: Tween
var _bar_hide_tween: Tween

@export var floor_collision_mask: int = 1
@export var floor_probe_height: float = 32.0
@export var floor_probe_depth: float = 64.0

@onready var body: CharacterBody3D = $Body
@onready var model_mesh: MeshInstance3D = $Body/Model/MeshInstance3D
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var display_name_label: Label = $DisplayNameLabel
@onready var hand_pivot: Node3D = $Body/Model/HandPivot
@onready var state_synchronizer: StateSynchronizer = $StateSynchronizer
@onready var stats_component: StatsComponent = $StatsComponent
@onready var equipment_component: EquipmentComponent = $EquipmentComponent


func _ready() -> void:
	if multiplayer.is_server():
		return
	_on_stat_changed(Stat.HEALTH, stats_component.get_stat(Stat.HEALTH))
	_on_stat_changed(Stat.HEALTH_MAX, stats_component.get_stat(Stat.HEALTH_MAX))
	stats_component.stats.stat_changed.connect(_on_stat_changed)
	set_health_bar_fill(BAR_COLOR_HOSTILE)
	if health_bar_auto_hide:
		progress_bar.hide()
	_sync_body_from_plane()


func _physics_process(_delta: float) -> void:
	_sync_body_from_plane()


func wants_net_smoothing() -> bool:
	return true


func net_apply_position(value: Vector2) -> void:
	if _net_smoother == null:
		_net_smoother = NetMotionSmoother.new()
		_net_smoother.name = "NetMotionSmoother"
		_net_smoother.delay_ms = net_smooth_delay_ms
		add_child(_net_smoother)
	_net_smoother.push_sample(value)


func apply_plane_position(plane: Vector2, snap_floor: bool = true) -> void:
	position = plane
	if snap_floor:
		_sync_body_from_plane()


func get_plane_position() -> Vector2:
	return Vector2(global_position.x, global_position.y)


func set_health_bar_fill(color: Color) -> void:
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	fill.anti_aliasing = false
	progress_bar.add_theme_stylebox_override(&"fill", fill)


func is_pvp() -> bool:
	return zone_flags & Map.ZoneMode.PVP


func has_modifier(mod: Map.ZoneModifiers) -> bool:
	var mask: int = 1 << (1 + mod)
	return (zone_flags & mask) != 0


func _sync_body_from_plane() -> void:
	if body == null:
		return
	var plane: Vector2 = global_position
	var floor_y: float = _sample_floor_y(plane)
	body.global_position = PlaneCoords3D.plane_to_world(plane, floor_y)


func _sample_floor_y(plane: Vector2) -> float:
	var world: Vector3 = PlaneCoords3D.plane_to_world(plane, body.global_position.y if body != null else 0.0)
	var from: Vector3 = world + Vector3.UP * floor_probe_height
	var to: Vector3 = world - Vector3.UP * floor_probe_depth
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, floor_collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return world.y
	return (hit.get("position", world) as Vector3).y


func _on_stat_changed(stat_name: StringName, value: float) -> void:
	if stat_name == Stat.HEALTH:
		if _last_health_seen < 0.0:
			progress_bar.value = value
		elif value != _last_health_seen:
			_set_bar_value(value)
			if value < _last_health_seen:
				_play_hit_feedback()
			if health_bar_auto_hide:
				_flash_health_bar()
		_last_health_seen = value
	if stat_name == Stat.HEALTH_MAX:
		progress_bar.max_value = value


func _play_hit_feedback() -> void:
	if model_mesh == null:
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_running():
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(model_mesh, ^"modulate", Color(2.0, 0.5, 0.5, 1.0), 0.05)
	_hit_flash_tween.tween_property(model_mesh, ^"modulate", Color.WHITE, 0.18)
	if is_instance_valid(Client) and Client.audio_manager != null:
		Client.audio_manager.play_sfx(
			"res://assets/audio/sfx/hit.wav",
			global_position
		)


func _set_bar_value(value: float) -> void:
	if _bar_value_tween != null and _bar_value_tween.is_valid():
		_bar_value_tween.kill()
	_bar_value_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bar_value_tween.tween_property(progress_bar, ^"value", value, 0.18)


func _flash_health_bar() -> void:
	var bar: CanvasItem = progress_bar
	bar.show()
	bar.modulate.a = 1.0
	if _bar_hide_tween != null and _bar_hide_tween.is_valid():
		_bar_hide_tween.kill()
	_bar_hide_tween = create_tween()
	_bar_hide_tween.tween_interval(4.0)
	_bar_hide_tween.tween_property(bar, ^"modulate:a", 0.0, 0.4)
	_bar_hide_tween.tween_callback(bar.hide)


func _set_skin_id(id: int) -> void:
	skin_id = id


func _set_anim(new_anim: Animations) -> void:
	anim = new_anim


func _set_flip(new_flip: bool) -> void:
	flipped = new_flip
	if model_mesh != null:
		model_mesh.scale.x = -1.0 if new_flip else 1.0


func _set_pivot(new_pivot: float) -> void:
	pivot = new_pivot
	if hand_pivot != null:
		hand_pivot.rotation.y = new_pivot


func _set_display_name(new_name: String) -> void:
	display_name = new_name
	if not multiplayer.is_server():
		display_name_changed.emit(new_name)
