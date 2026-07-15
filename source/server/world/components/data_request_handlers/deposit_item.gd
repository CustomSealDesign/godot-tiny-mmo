extends DataRequestHandler
## Client -> server: deposit the full stack from an inventory slot into the Sect Vault.


const INTERACT_RANGE: float = 90.0


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"deposit_item", 12, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}

	var resource: PlayerResource = player.player_resource
	if resource == null:
		return {"ok": false, "reason": "invalid"}

	if not _near_vault(player, instance, args):
		return {"ok": false, "reason": "too_far"}

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

	if not BankInventory.can_add_item(resource.bank_inventory, item_id, quantity):
		return {"ok": false, "reason": "bank_full"}

	var bank_result: Dictionary = BankInventory.add_item(resource.bank_inventory, item_id, quantity)
	if not bool(bank_result.get("ok", false)):
		return {"ok": false, "reason": str(bank_result.get("reason", "bank_full"))}

	slots[slot_index] = {"item_id": 0, "quantity": 0}

	if WorldServer.curr != null:
		WorldServer.curr.database.save_player(resource)

	InventorySlotService.push_to_peer(peer_id, resource)
	BankInventoryService.push_to_peer(peer_id, resource)

	return {
		"ok": true,
		"item_id": item_id,
		"quantity": quantity,
		"slots": SlotInventory.to_payload(resource.slot_inventory),
		"bank_slots": BankInventory.to_payload(resource.bank_inventory),
	}


func _near_vault(player: Player, instance: ServerInstance, args: Dictionary) -> bool:
	var vault_name: StringName = StringName(str(args.get("vault", "")))
	if vault_name.is_empty():
		return false
	var map: Map = instance.instance_map
	if map == null or not map.sect_vaults.has(vault_name):
		return false
	var vault: SectVault = map.sect_vaults[vault_name] as SectVault
	return player.global_position.distance_to(vault.global_position) <= INTERACT_RANGE
