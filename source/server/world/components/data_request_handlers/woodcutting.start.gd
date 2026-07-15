extends DataRequestHandler
## Client -> server: begin woodcutting at a spirit tree once in range.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"woodcutting.start", 6, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}
	if player.get_node_or_null(^"ChannelInstance") != null:
		return {"ok": false, "reason": "channeling"}

	var tree_name: StringName = StringName(str(args.get("tree", "")))
	if tree_name.is_empty():
		return {"ok": false, "reason": "no_tree"}

	var map: Map = instance.instance_map
	if map == null or not map.spirit_trees.has(tree_name):
		return {"ok": false, "reason": "unknown_tree"}

	var tree: SpiritTree = map.spirit_trees[tree_name] as SpiritTree
	return WoodcuttingService.start(peer_id, player, tree, instance)
