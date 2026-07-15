extends DataRequestHandler
## Client -> server: unequip an OSRS gear slot back into the bag.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"unequip_item", 12, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}

	var resource: PlayerResource = player.player_resource
	if resource == null:
		return {"ok": false, "reason": "invalid"}

	var slot_key: StringName = StringName(str(args.get("slot", "")))
	if slot_key.is_empty() or not PlayerResource.OSRS_EQUIPMENT_SLOTS.has(slot_key):
		return {"ok": false, "reason": "invalid_slot"}

	resource.ensure_osrs_equipment()
	var item_id: int = resource.get_osrs_equipped_item(slot_key)
	if item_id <= 0:
		return {"ok": false, "reason": "empty_slot"}

	if not SlotInventory.can_add_item(resource.slot_inventory, item_id, 1):
		_push_system_message(peer_id, "Your inventory is full.")
		return {"ok": false, "reason": "inventory_full"}

	var add_result: Dictionary = SlotInventory.add_item(resource.slot_inventory, item_id, 1)
	if not bool(add_result.get("ok", false)):
		_push_system_message(peer_id, "Your inventory is full.")
		return {"ok": false, "reason": "inventory_full"}

	resource.equipment[slot_key] = 0

	if WorldServer.curr != null:
		WorldServer.curr.database.save_player(resource)

	InventorySlotService.push_to_peer(peer_id, resource)
	EquipmentService.push_to_peer(peer_id, resource)

	return {
		"ok": true,
		"slot": String(slot_key),
		"item_id": item_id,
		"slots": SlotInventory.to_payload(resource.slot_inventory),
		"equipment": EquipmentService.payload(resource).get("equipment", {}),
	}


func _push_system_message(peer_id: int, message: String) -> void:
	if WorldServer.curr == null or peer_id <= 0 or message.is_empty():
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"system.message", {"message": message})
