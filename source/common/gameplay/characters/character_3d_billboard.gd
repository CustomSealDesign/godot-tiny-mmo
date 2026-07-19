class_name Character3DBillboard
extends Node3D
## Client-only: renders the parent 2D [Character]'s AnimatedSprite2D as a billboard in the
## 3D world, so NPCs and hostile mobs (which are all built from the 2D character.tscn) are
## visible under the Camera3D instead of stuck to the screen. It only MIRRORS the existing
## 2D sprite each frame and repositions the name/health Controls — the character's own 2D
## logic, physics and the server are untouched. (Players don't use character.tscn on the
## client — they use player_3d.tscn — so this runs only for NPCs/mobs.)

@export var floor_collision_mask: int = 1

var _character: Node2D
var _src: AnimatedSprite2D
var _sprite: Sprite3D
var _bar: Control
var _name: Control


func _ready() -> void:
	if multiplayer.is_server():
		return
	_character = get_parent() as Node2D
	if _character == null:
		return
	_src = _character.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
	if _src == null:
		return
	# Hide the 2D visual + weapon rig (they'd draw in screen space under a Camera3D).
	_src.visible = false
	var hand: Node = _character.get_node_or_null(^"HandOffset")
	if hand is CanvasItem:
		(hand as CanvasItem).visible = false

	_bar = _character.get_node_or_null(^"ProgressBar") as Control
	_name = _character.get_node_or_null(^"DisplayNameLabel") as Control

	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.pixel_size = PixelScale3D.SPRITE_PIXEL_SIZE
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.shaded = false
	_sprite.transparent = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(_sprite)


func _process(_delta: float) -> void:
	if _sprite == null or _src == null or not is_instance_valid(_character):
		return

	# Mirror the current animation frame onto the billboard, scaled to a consistent world
	# height regardless of the source sprite's pixel resolution (fixes tiny/huge mismatches).
	var frames: SpriteFrames = _src.sprite_frames
	if frames != null and frames.has_animation(_src.animation):
		var tex: Texture2D = frames.get_frame_texture(_src.animation, _src.frame)
		if tex != null:
			_sprite.texture = tex
			_sprite.pixel_size = PixelScale3D.CHARACTER_WORLD_HEIGHT / float(maxi(1, tex.get_height()))
	_sprite.flip_h = _src.flip_h

	# Stand the billboard on the floor at the character's plane position.
	var plane: Vector2 = _character.global_position
	var floor_y: float = _sample_floor_y(plane)
	var world: Vector3 = PlaneCoords3D.plane_to_world(plane, floor_y)
	var height_world: float = PixelScale3D.CHARACTER_WORLD_HEIGHT
	_sprite.global_position = world + Vector3.UP * (height_world * 0.5)

	# Keep the 2D health bar + name label pinned over the billboard.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var anchor: Vector3 = world + Vector3.UP * (height_world + 8.0)
		if _bar != null:
			OverheadUi3D.place(_bar, camera, anchor)
		if _name != null:
			OverheadUi3D.place(_name, camera, anchor, Vector2(0.0, -14.0))


func _sample_floor_y(plane: Vector2) -> float:
	var world: Vector3 = PlaneCoords3D.plane_to_world(plane, 0.0)
	var viewport: Viewport = get_viewport()
	if viewport == null or viewport.world_3d == null:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(world + Vector3.UP * 32.0, world - Vector3.UP * 64.0, floor_collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = viewport.world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return (hit.get("position", world) as Vector3).y
