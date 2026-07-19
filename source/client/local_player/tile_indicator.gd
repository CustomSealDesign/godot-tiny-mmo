class_name TileIndicator
extends Node3D


@onready var mesh_instance: MeshInstance3D = $IndicatorMesh


func set_tile_shape(corners: Array) -> void:
	var local_vertices := PackedVector3Array()
	for corner: Vector3 in corners:
		local_vertices.append(corner - global_position)

	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = local_vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.flags_transparent = true
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat


func show_at_world(world_position: Vector3) -> void:
	global_position = world_position
	var half: float = GridMovement.HALF_TILE
	var corners: Array = [
		world_position + Vector3(-half, 0.05, -half),
		world_position + Vector3(half, 0.05, -half),
		world_position + Vector3(half, 0.05, half),
		world_position + Vector3(-half, 0.05, half),
	]
	set_tile_shape(corners)
