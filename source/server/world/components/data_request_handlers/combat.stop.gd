extends DataRequestHandler
## Client -> server: leave an active OSRS-style combat session.


func data_request_handler(peer_id: int, instance: ServerInstance, _args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"combat.stop", 12, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null:
		return {"ok": false, "reason": "invalid"}

	OsrsCombatService.stop(peer_id, "cancelled")
	return {"ok": true}
