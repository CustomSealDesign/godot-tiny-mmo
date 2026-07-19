@icon("res://assets/node_icons/color/icon_map_colored.png")
class_name TileFloor3D
extends Node3D
## Bakes a map's 2D pixel-art TileMapLayer(s) into the "pixel-scale 3D" world:
## a textured 3D floor, an upright billboard per blocking prop, and — critically —
## a walkable-floor collider (physics layer 1) covering ONLY the walkable cells.
##
## Why this exists: the client's grid pathfinder / click-to-move decides walkability
## by raycasting DOWN and asking "is there floor here?" (see [GridPathfinder] and
## [Character3DClient._sample_floor_y]). So a tile is blocked simply by having NO
## layer-1 collider under it. The old approach (one big flat box under the whole map)
## made every tile — walls included — walkable. This baker instead emits floor
## collision cell-by-cell, minus blocked cells, so obstacles are correctly unwalkable.
##
## Walkability source: a tile is a BLOCKING upright prop if its TileData carries a
## physics collision polygon (trees, walls, rocks are authored that way). Everything
## else is flat, walkable ground. This needs no extra authoring on existing tilesets.
##
## Runs on the CLIENT only — the headless server is 2D and does no walkability check,
## so it never needs the 3D floor. Baked geometry is generated at load and never saved
## into the .tscn (keeps map scenes tiny and always in sync with the source tiles).


## TileMapLayers to bake. Each is read for both floor tiles and blocking props. Leave
## empty to auto-collect every TileMapLayer sibling under the owning Map.
@export var tile_layers: Array[NodePath] = []

## World Y of the floor plane. Matches [PlaneCoords3D] (plane -> world y = 0).
@export var floor_y: float = 0.0

## Treat tiles that carry a physics collision polygon as blocking upright props.
@export var blocking_from_collision: bool = true

## Render blocking tiles as upright Y-billboards standing on the floor (trees, walls).
## When false they are laid flat like ground (useful for flat decals authored with a
## collision poly).
@export var props_upright: bool = true

## Extra world-unit nudge applied to every baked upright prop's vertical position.
## Exposed for quick in-editor tuning without touching code.
@export var prop_y_offset: float = 0.0

## Hide the source 2D TileMapLayers on the client after baking (their pixels are now
## drawn by the 3D mesh; under a Camera3D the raw 2D layer would smear in screen space).
@export var hide_source_layers: bool = true

const _BAKED_ROOT_NAME: StringName = &"__Baked3D"


func _ready() -> void:
	# CLIENT ONLY. The headless world server also instantiates this map (maps are shared
	# scenes) but is 2D and does no walkability check, so it must never bake — building a
	# 3D floor + physics there is pointless and was crashing world spin-up. Detect the
	# server by its headless DisplayServer: this is dependency-free (referencing GameMode
	# from a map-loaded script pulled it into the scene's load graph and segfaulted the
	# server). NB: this node is deliberately NOT @tool — baking during editor import
	# instantiation also crashed the headless server.
	if DisplayServer.get_name() == "headless":
		return
	bake()


## (Re)build all baked geometry. Idempotent — clears the previous bake first.
func bake() -> void:
	_clear_baked()

	var layers: Array[TileMapLayer] = _resolve_layers()
	if layers.is_empty():
		return

	var baked_root := Node3D.new()
	baked_root.name = _BAKED_ROOT_NAME
	add_child(baked_root)
	# Transient: never persisted into the scene, always regenerated at load/preview.

	# floor_cells: cells that have a walkable ground tile. blocked_cells: cells covered
	# by a blocking prop (collision poly). walkable = floor - blocked.
	var floor_cells: Dictionary = {}         # Vector2i -> true
	var blocked_cells: Dictionary = {}       # Vector2i -> true
	var floor_surfaces: Dictionary = {}      # Texture2D -> SurfaceTool (batched flat floor)
	var props: Array = []                    # [{tex, region, world_center, height_px, width_px}]

	for layer: TileMapLayer in layers:
		var tile_set: TileSet = layer.tile_set
		if tile_set == null:
			continue
		var has_physics: bool = tile_set.get_physics_layers_count() > 0
		for cell: Vector2i in layer.get_used_cells():
			var source_id: int = layer.get_cell_source_id(cell)
			if source_id < 0:
				continue
			var source: TileSetSource = tile_set.get_source(source_id)
			if not (source is TileSetAtlasSource):
				continue
			var atlas := source as TileSetAtlasSource
			var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
			var tile_data: TileData = layer.get_cell_tile_data(cell)
			var region: Rect2i = atlas.get_tile_texture_region(atlas_coords)
			var texture: Texture2D = atlas.texture
			if texture == null:
				continue

			var is_blocking: bool = blocking_from_collision and has_physics \
				and tile_data != null and tile_data.get_collision_polygons_count(0) > 0

			# Cell center in the gameplay plane (Vector2), then into the 3D world.
			var plane_center: Vector2 = layer.to_global(layer.map_to_local(cell))
			var world_center: Vector3 = PlaneCoords3D.plane_to_world(plane_center, floor_y)

			if is_blocking:
				_mark_blocked(blocked_cells, layer, cell)
				if props_upright:
					var tex_origin: Vector2 = Vector2(tile_data.texture_origin) if tile_data != null else Vector2.ZERO
					props.append({
						"tex": texture,
						"region": region,
						"center": world_center,
						"tex_origin": tex_origin,
					})
					continue
				# else fall through and lay it flat like floor (no walkable contribution)
			else:
				floor_cells[cell] = true

			# Flat quad (floor tile, or a flat-laid blocking tile).
			var st: SurfaceTool = floor_surfaces.get(texture)
			if st == null:
				st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				floor_surfaces[texture] = st
			_add_flat_quad(st, world_center, region, texture.get_size())

	_build_floor_mesh(baked_root, floor_surfaces)
	_build_props(baked_root, props)
	_build_walkable_collider(baked_root, floor_cells, blocked_cells, layers)

	if hide_source_layers and not Engine.is_editor_hint():
		for layer: TileMapLayer in layers:
			layer.visible = false


## Blocked cells are tracked in the SAME grid coordinates as floor_cells (the tile
## layer's cell coords). A blocking multi-cell tile (a wide tree) still anchors to one
## cell; we block that anchor cell. Sub-tile precision is unnecessary for grid movement.
func _mark_blocked(blocked: Dictionary, _layer: TileMapLayer, cell: Vector2i) -> void:
	blocked[cell] = true


func _add_flat_quad(st: SurfaceTool, center: Vector3, region: Rect2i, tex_size: Vector2) -> void:
	# Half-extent from the region size (world units == pixels). Ground tiles are the
	# tileset tile_size; larger regions simply cover more ground.
	var hx: float = float(region.size.x) * 0.5
	var hz: float = float(region.size.y) * 0.5
	var u0: float = float(region.position.x) / tex_size.x
	var v0: float = float(region.position.y) / tex_size.y
	var u1: float = float(region.position.x + region.size.x) / tex_size.x
	var v1: float = float(region.position.y + region.size.y) / tex_size.y

	# Corners on the XZ plane. 2D +y maps to world +z, so region top (v0) -> -z.
	var nw := Vector3(center.x - hx, center.y, center.z - hz)
	var ne := Vector3(center.x + hx, center.y, center.z - hz)
	var se := Vector3(center.x + hx, center.y, center.z + hz)
	var sw := Vector3(center.x - hx, center.y, center.z + hz)

	st.set_normal(Vector3.UP)
	# Triangle 1: nw, ne, se
	st.set_uv(Vector2(u0, v0)); st.add_vertex(nw)
	st.set_uv(Vector2(u1, v0)); st.add_vertex(ne)
	st.set_uv(Vector2(u1, v1)); st.add_vertex(se)
	# Triangle 2: nw, se, sw
	st.set_uv(Vector2(u0, v0)); st.add_vertex(nw)
	st.set_uv(Vector2(u1, v1)); st.add_vertex(se)
	st.set_uv(Vector2(u0, v1)); st.add_vertex(sw)


func _build_floor_mesh(parent: Node3D, surfaces: Dictionary) -> void:
	for texture: Texture2D in surfaces:
		var st: SurfaceTool = surfaces[texture]
		var mesh: ArrayMesh = st.commit()
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _pixel_material(texture)
		parent.add_child(mi)


func _build_props(parent: Node3D, props: Array) -> void:
	for p: Dictionary in props:
		var texture: Texture2D = p["tex"]
		var region: Rect2i = p["region"]
		var center: Vector3 = p["center"]

		var atlas_tex := AtlasTexture.new()
		atlas_tex.atlas = texture
		atlas_tex.region = Rect2(region)

		var sprite := Sprite3D.new()
		sprite.texture = atlas_tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if props_upright else BaseMaterial3D.BILLBOARD_DISABLED
		sprite.pixel_size = PixelScale3D.SPRITE_PIXEL_SIZE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.transparent = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		# Stand the billboard on the floor: raise it by half its (scaled) height.
		var height_world: float = float(region.size.y) * sprite.pixel_size
		sprite.position = Vector3(center.x, floor_y + height_world * 0.5 + prop_y_offset, center.z)
		parent.add_child(sprite)


## One StaticBody3D (physics layer 1) covering the walkable cells with thin SOLID box
## slabs. Solid boxes — not a flat trimesh — because a zero-thickness ConcavePolygonShape3D
## is NOT reliably hit by the downward raycasts the pathfinder / floor-snap depend on
## (coplanar faces get missed), which silently breaks movement. Cells are greedy-merged
## into maximal rectangles first, so a big open field is a handful of boxes, not thousands.
const _FLOOR_SLAB_THICKNESS: float = 0.5

func _build_walkable_collider(parent: Node3D, floor_cells: Dictionary, blocked_cells: Dictionary, layers: Array[TileMapLayer]) -> void:
	if layers.is_empty():
		return
	var ref_layer: TileMapLayer = layers[0]
	var tile_px: Vector2i = ref_layer.tile_set.tile_size
	var hx: float = float(tile_px.x) * 0.5
	var hz: float = float(tile_px.y) * 0.5

	# walkable = floor minus blocked (tree/wall) cells.
	var walkable: Dictionary = {}
	for cell: Vector2i in floor_cells:
		if not blocked_cells.has(cell):
			walkable[cell] = true
	if walkable.is_empty():
		return

	var body := StaticBody3D.new()
	body.name = &"WalkableFloor"
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	# Greedy rectangle meshing over the walkable cell set.
	var visited: Dictionary = {}
	for cell: Vector2i in walkable:
		if visited.has(cell):
			continue
		# Extend right along the row.
		var x1: int = cell.x
		while walkable.has(Vector2i(x1 + 1, cell.y)) and not visited.has(Vector2i(x1 + 1, cell.y)):
			x1 += 1
		# Extend down while whole rows [cell.x..x1] are free.
		var y1: int = cell.y
		var growing: bool = true
		while growing:
			var ny: int = y1 + 1
			for xx: int in range(cell.x, x1 + 1):
				var probe: Vector2i = Vector2i(xx, ny)
				if not walkable.has(probe) or visited.has(probe):
					growing = false
					break
			if growing:
				y1 = ny
		for yy: int in range(cell.y, y1 + 1):
			for xx: int in range(cell.x, x1 + 1):
				visited[Vector2i(xx, yy)] = true

		# World AABB of the rectangle from its corner cell centers.
		var c0: Vector3 = PlaneCoords3D.plane_to_world(ref_layer.to_global(ref_layer.map_to_local(Vector2i(cell.x, cell.y))), floor_y)
		var c1: Vector3 = PlaneCoords3D.plane_to_world(ref_layer.to_global(ref_layer.map_to_local(Vector2i(x1, y1))), floor_y)
		var min_x: float = minf(c0.x, c1.x) - hx
		var max_x: float = maxf(c0.x, c1.x) + hx
		var min_z: float = minf(c0.z, c1.z) - hz
		var max_z: float = maxf(c0.z, c1.z) + hz

		var box := BoxShape3D.new()
		box.size = Vector3(max_x - min_x, _FLOOR_SLAB_THICKNESS, max_z - min_z)
		var col := CollisionShape3D.new()
		col.shape = box
		# Slab top flush with the floor plane; extends downward by the thickness.
		col.position = Vector3((min_x + max_x) * 0.5, floor_y - _FLOOR_SLAB_THICKNESS * 0.5, (min_z + max_z) * 0.5)
		body.add_child(col)


func _pixel_material(texture: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _resolve_layers() -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	if not tile_layers.is_empty():
		for path: NodePath in tile_layers:
			var node: Node = get_node_or_null(path)
			if node is TileMapLayer:
				out.append(node)
		return out
	# Auto-collect when none are specified: search the owning scene (the Map root is
	# our `owner` once instanced) or, failing that, our parent. Kept free of the Map
	# type so the baker stays a standalone, independently testable component.
	var scope: Node = owner if owner != null else get_parent()
	if scope != null:
		for node: Node in scope.find_children("*", "TileMapLayer", true, false):
			out.append(node)
	return out


func _clear_baked() -> void:
	var existing: Node = get_node_or_null(NodePath(_BAKED_ROOT_NAME))
	if existing != null:
		existing.free()
