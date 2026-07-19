extends DataRequestHandler
## Client -> server: equip an item from a bag slot into its OSRS gear slot.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"equip_item", 12, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}

	var resource: PlayerResource = player.player_resource
	if resource == null:
		return {"ok": false, "reason": "invalid"}

	var slot_index: int = int(args.get("slot_index", -1))
	if slot_index < 0 or slot_index >= SlotInventory.SLOT_COUNT:
		return {"ok": false, "reason": "invalid_slot"}

	var slots: Array = resource.slot_inventory
	if slot_index >= slots.size():
		return {"ok": false, "reason": "invalid_slot"}

	var slot: Dictionary = slots[slot_index] as Dictionary
	var item_id: int = int(slot.get("item_id", 0))
	var quantity: int = int(slot.get("quantity", 0))
	if item_id <= 0 or quantity <= 0:
		return {"ok": false, "reason": "empty_slot"}

	var equip_slot: String = ItemDatabase.get_equip_slot(item_id)
	if equip_slot.is_empty():
		return {"ok": false, "reason": "not_equippable"}

	var slot_key: StringName = StringName(equip_slot)
	if not PlayerResource.OSRS_EQUIPMENT_SLOTS.has(slot_key):
		return {"ok": false, "reason": "invalid_slot"}

	resource.ensure_osrs_equipment()
	var previous_id: int = resource.get_osrs_equipped_item(slot_key)

	# Remove one from the clicked inventory slot.
	var remove_result: Dictionary = SlotInventory.remove_one_from_slot(slots, slot_index)
	if not bool(remove_result.get("ok", false)):
		return {"ok": false, "reason": "remove_failed"}

	# If something was already equipped, return it to the same inventory slot (swap).
	if previous_id > 0:
		slots[slot_index] = {"item_id": previous_id, "quantity": 1}
	else:
		slots[slot_index] = {"item_id": 0, "quantity": 0}

	resource.equipment[slot_key] = item_id

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
