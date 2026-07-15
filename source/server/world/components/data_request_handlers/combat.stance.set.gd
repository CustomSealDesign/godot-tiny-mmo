extends DataRequestHandler
## Client -> server: set the active melee combat stance.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"combat.stance.set", 12, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.player_resource == null:
		return {"ok": false, "reason": "invalid"}

	var stance: String = str(args.get("stance", ""))
	if stance not in ["accurate", "aggressive", "defensive"]:
		return {"ok": false, "reason": "invalid_stance"}

	var resource: PlayerResource = player.player_resource
	resource.set_combat_stance(stance)

	if WorldServer.curr != null:
		WorldServer.curr.database.save_player(resource)

	CombatStateService.push_to_peer(peer_id, resource)
	return {"ok": true, "combat_stance": resource.get_combat_stance()}
