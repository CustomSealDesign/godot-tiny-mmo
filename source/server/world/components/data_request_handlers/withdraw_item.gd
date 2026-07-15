extends DataRequestHandler
## Client -> server: withdraw one item from a bank slot into the player inventory.


const INTERACT_RANGE: float = 90.0


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"withdraw_item", 12, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}

	var resource: PlayerResource = player.player_resource
	if resource == null:
		return {"ok": false, "reason": "invalid"}

	if not _near_vault(player, instance, args):
		return {"ok": false, "reason": "too_far"}

	var bank_slot_index: int = int(args.get("bank_slot_index", -1))
	if bank_slot_index < 0 or bank_slot_index >= BankInventory.SLOT_COUNT:
		return {"ok": false, "reason": "invalid_slot"}

	var bank_slots: Array = resource.bank_inventory
	if bank_slot_index >= bank_slots.size():
		return {"ok": false, "reason": "invalid_slot"}

	var bank_slot: Dictionary = bank_slots[bank_slot_index] as Dictionary
	var item_id: int = int(bank_slot.get("item_id", 0))
	var quantity: int = int(bank_slot.get("quantity", 0))
	if item_id <= 0 or quantity <= 0:
		return {"ok": false, "reason": "empty_slot"}

	var withdraw_amount: int = mini(1, quantity)
	if not SlotInventory.can_add_item(resource.slot_inventory, item_id, withdraw_amount):
		return {"ok": false, "reason": "inventory_full"}

	var remove_result: Dictionary = BankInventory.remove_amount_from_slot(
		bank_slots,
		bank_slot_index,
		withdraw_amount
	)
	if not bool(remove_result.get("ok", false)):
		return {"ok": false, "reason": str(remove_result.get("reason", "remove_failed"))}

	var add_result: Dictionary = SlotInventory.add_item(
		resource.slot_inventory,
		item_id,
		withdraw_amount
	)
	if not bool(add_result.get("ok", false)):
		# Roll back the bank removal if inventory add fails.
		BankInventory.add_item(bank_slots, item_id, withdraw_amount)
		return {"ok": false, "reason": "inventory_full"}

	if WorldServer.curr != null:
		WorldServer.curr.database.save_player(resource)

	InventorySlotService.push_to_peer(peer_id, resource)
	BankInventoryService.push_to_peer(peer_id, resource)

	return {
		"ok": true,
		"item_id": item_id,
		"quantity": withdraw_amount,
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
