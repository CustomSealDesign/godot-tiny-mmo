class_name GroundItemService
extends RefCounted
## Server-authoritative floor loot spawned from defeated enemies.


static var _next_ground_item_id: int = 1


static func spawn_loot(
	instance: ServerInstance,
	grid: Vector2i,
	item_id: int,
	quantity: int
) -> GroundItem:
	if instance == null or instance.instance_map == null:
		return null
	var map: Map = instance.instance_map
	var container: ReplicatedPropsContainer = map.replicated_props_container
	if container == null:
		return null
	if not ItemDatabase.has_item(item_id) or quantity <= 0:
		return null

	var ground_item_id: int = _alloc_ground_item_id()
	var plane: Vector2 = GridMovement.grid_to_plane(grid)
	var init: Dictionary = {
		"ground_item_id": ground_item_id,
		"item_id": item_id,
		"quantity": quantity,
	}
	var node: Node = container.spawn_dynamic(ReplicatedPropsContainer.SCENE_GROUND_ITEM, plane, init)
	var ground_item: GroundItem = node as GroundItem
	if ground_item == null:
		return null
	map.register_keyed(map.ground_items, ground_item_id, ground_item, "ground item")
	return ground_item


static func pickup(peer_id: int, player: Player, ground_item_id: int, instance: ServerInstance) -> Dictionary:
	if player == null or player.is_dead or instance == null or instance.instance_map == null:
		return {"ok": false, "reason": "invalid"}

	var map: Map = instance.instance_map
	if not map.ground_items.has(ground_item_id):
		return {"ok": false, "reason": "missing"}

	var ground_item: GroundItem = map.ground_items[ground_item_id] as GroundItem
	if ground_item == null or not is_instance_valid(ground_item):
		map.ground_items.erase(ground_item_id)
		return {"ok": false, "reason": "missing"}

	if player.global_position.distance_to(ground_item.global_position) > OsrsCombatService.INTERACT_RANGE:
		return {"ok": false, "reason": "too_far"}

	var resource: PlayerResource = player.player_resource
	var item_id: int = ground_item.item_id
	var quantity: int = ground_item.quantity
	if not SlotInventory.can_add_item(resource.slot_inventory, item_id, quantity):
		_push_system_message(peer_id, "Not enough inventory space")
		return {"ok": false, "reason": "inventory_full"}

	var add_result: Dictionary = SlotInventory.add_item(resource.slot_inventory, item_id, quantity)
	if not bool(add_result.get("ok", false)):
		_push_system_message(peer_id, "Not enough inventory space")
		return {"ok": false, "reason": "inventory_full"}

	despawn(ground_item, map)
	if WorldServer.curr != null:
		WorldServer.curr.database.save_player(resource)
	InventorySlotService.push_to_peer(peer_id, resource)
	return {
		"ok": true,
		"item_id": item_id,
		"quantity": quantity,
		"item_name": ItemDatabase.get_name(item_id),
	}


static func despawn(ground_item: GroundItem, map: Map) -> void:
	if ground_item == null:
		return
	var ground_item_id: int = ground_item.ground_item_id
	if map != null:
		map.ground_items.erase(ground_item_id)

	var container: ReplicatedPropsContainer = ground_item.get_container()
	if container == null:
		ground_item.queue_free()
		return

	var child_id: int = container.child_id_of_node(ground_item)
	if child_id >= 0:
		container.despawn_dynamic(child_id)
	else:
		ground_item.queue_free()


static func _alloc_ground_item_id() -> int:
	var id: int = _next_ground_item_id
	_next_ground_item_id += 1
	return id


static func _push_system_message(peer_id: int, message: String) -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"system.message", {"message": message})
