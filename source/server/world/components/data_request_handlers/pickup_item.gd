extends DataRequestHandler
## Client -> server: pick up a floor loot pile once standing on its tile.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"pickup_item", 12, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}

	var ground_item_id: int = int(args.get("ground_item_id", 0))
	if ground_item_id <= 0:
		return {"ok": false, "reason": "invalid_item"}

	return GroundItemService.pickup(peer_id, player, ground_item_id, instance)
