extends DataRequestHandler
## Client -> server: consume one item from the 28-slot bag for Qi.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"consume_item", 8, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}

	var slot_index: int = int(args.get("slot_index", -1))
	if slot_index < 0 or slot_index >= SlotInventory.SLOT_COUNT:
		return {"ok": false, "reason": "invalid_slot"}

	var resource: PlayerResource = player.player_resource
	if resource == null:
		return {"ok": false, "reason": "invalid"}

	var slots: Array = resource.slot_inventory
	if slot_index >= slots.size():
		return {"ok": false, "reason": "invalid_slot"}

	var slot: Dictionary = slots[slot_index] as Dictionary
	var item_id: int = int(slot.get("item_id", 0))
	var quantity: int = int(slot.get("quantity", 0))
	if item_id <= 0 or quantity <= 0:
		return {"ok": false, "reason": "empty_slot"}

	var qi_value: int = ItemDatabase.get_qi_value(item_id)
	if qi_value <= 0:
		return {"ok": false, "reason": "not_consumable"}

	var remove_result: Dictionary = SlotInventory.remove_one_from_slot(slots, slot_index)
	if not bool(remove_result.get("ok", false)):
		return {"ok": false, "reason": str(remove_result.get("reason", "remove_failed"))}

	var breakthrough: Dictionary = CultivationService.grant_qi(resource, qi_value)
	if WorldServer.curr != null:
		WorldServer.curr.database.save_player(resource)

	InventorySlotService.push_to_peer(peer_id, resource)
	CultivationService.push_to_peer(peer_id, resource)

	return {
		"ok": true,
		"slot_index": slot_index,
		"item_id": item_id,
		"item_name": ItemDatabase.get_name(item_id),
		"qi_gained": qi_value,
		"qi_level": resource.qi_level,
		"cultivation_realm": resource.cultivation_realm,
		"broke_through": bool(breakthrough.get("broke_through", false)),
		"slots": SlotInventory.to_payload(resource.slot_inventory),
	}
