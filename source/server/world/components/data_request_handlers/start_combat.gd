extends DataRequestHandler
## Client -> server: begin OSRS-style melee combat against an enemy once in range.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"start_combat", 6, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}
	if player.get_node_or_null(^"ChannelInstance") != null:
		return {"ok": false, "reason": "channeling"}

	var enemy_name: StringName = StringName(str(args.get("enemy", "")))
	if enemy_name.is_empty():
		return {"ok": false, "reason": "no_enemy"}

	var map: Map = instance.instance_map
	if map == null or not map.enemies.has(enemy_name):
		return {"ok": false, "reason": "unknown_enemy"}

	var enemy: Enemy = map.enemies[enemy_name] as Enemy
	return OsrsCombatService.start(peer_id, player, enemy, instance)
