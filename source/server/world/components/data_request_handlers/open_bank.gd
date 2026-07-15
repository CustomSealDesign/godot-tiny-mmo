extends DataRequestHandler
## Client -> server: authorize opening the Sect Vault once in range.


const INTERACT_RANGE: float = 90.0


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"open_bank", 6, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}

	var vault_name: StringName = StringName(str(args.get("vault", "")))
	if vault_name.is_empty():
		return {"ok": false, "reason": "no_vault"}

	var map: Map = instance.instance_map
	if map == null or not map.sect_vaults.has(vault_name):
		return {"ok": false, "reason": "unknown_vault"}

	var vault: SectVault = map.sect_vaults[vault_name] as SectVault
	if player.global_position.distance_to(vault.global_position) > INTERACT_RANGE:
		return {"ok": false, "reason": "too_far"}

	var resource: PlayerResource = player.player_resource
	if resource == null:
		return {"ok": false, "reason": "invalid"}

	InventorySlotService.push_to_peer(peer_id, resource)
	BankInventoryService.push_to_peer(peer_id, resource)

	return {
		"ok": true,
		"slots": SlotInventory.to_payload(resource.slot_inventory),
		"bank_slots": BankInventory.to_payload(resource.bank_inventory),
	}
