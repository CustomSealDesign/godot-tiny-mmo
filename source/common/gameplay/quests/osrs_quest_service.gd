class_name OsrsQuestService
extends RefCounted
## Server-side helper for OSRS-style dialogue quest state, turn-in validation, and client sync.


static func payload(resource: PlayerResource) -> Dictionary:
	var out: Dictionary = {}
	for quest_id: StringName in QuestDatabase.QUESTS:
		out[String(quest_id)] = resource.get_osrs_quest_state(quest_id)
	return {"quests": out}


static func push_to_peer(peer_id: int, resource: PlayerResource) -> void:
	if WorldServer.curr == null or peer_id <= 0 or resource == null:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"quests.update", payload(resource))


static func push_dialogue(peer_id: int, dialogue: Dictionary) -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"dialogue.push", dialogue)


static func handle_interact(
	peer_id: int,
	player: Player,
	instance: ServerInstance,
	npc_id: StringName
) -> Dictionary:
	if player == null or player.player_resource == null or instance == null:
		return {"ok": false, "reason": "invalid"}

	var quest_id: StringName = QuestDatabase.quest_for_npc(npc_id)
	if quest_id.is_empty():
		return {"ok": false, "reason": "unknown_npc"}

	var npc: Node = instance.instance_map.dialogue_npcs.get(npc_id, null)
	if npc == null or not is_instance_valid(npc):
		return {"ok": false, "reason": "missing_npc"}

	if player.global_position.distance_to(npc.global_position) > _interact_range(npc):
		return {"ok": false, "reason": "too_far"}

	var resource: PlayerResource = player.player_resource
	var quest: Dictionary = QuestDatabase.get_quest(quest_id)
	var state: int = resource.get_osrs_quest_state(quest_id)

	match state:
		QuestDatabase.State.UNSTARTED:
			push_dialogue(peer_id, {
				"npc": str(quest.get("npc_name", "NPC")),
				"text": "Disciple, bring me 3 Wolf Cores.",
				"quest_id": String(quest_id),
				"show_accept": true,
				"button_label": "Accept",
			})
		QuestDatabase.State.IN_PROGRESS:
			var required_item_id: int = int(quest.get("required_item_id", 0))
			var required_amount: int = int(quest.get("required_amount", 0))
			if SlotInventory.has_amount(resource.slot_inventory, required_item_id, required_amount):
				if not SlotInventory.remove_amount_by_id(
						resource.slot_inventory,
						required_item_id,
						required_amount
					):
					push_dialogue(peer_id, {
						"npc": str(quest.get("npc_name", "NPC")),
						"text": "You lack the cores. Return when you have 3.",
						"quest_id": String(quest_id),
						"show_accept": false,
						"button_label": "Continue",
					})
					return {"ok": true}

				var reward_item_id: int = int(quest.get("reward_item_id", 0))
				var reward_quantity: int = int(quest.get("reward_item_quantity", 1))
				var add_result: Dictionary = SlotInventory.add_item(
					resource.slot_inventory,
					reward_item_id,
					reward_quantity
				)
				if not bool(add_result.get("ok", false)):
					push_dialogue(peer_id, {
						"npc": str(quest.get("npc_name", "NPC")),
						"text": "Your inventory is full. Make room and return.",
						"quest_id": String(quest_id),
						"show_accept": false,
						"button_label": "Continue",
					})
					return {"ok": true}

				var combat_xp: int = int(quest.get("combat_xp_reward", 0))
				OsrsSkillService.add_xp(resource, SkillManager.COMBAT, combat_xp)
				resource.set_osrs_quest_state(quest_id, QuestDatabase.State.COMPLETED)

				if WorldServer.curr != null:
					WorldServer.curr.database.save_player(resource)
				InventorySlotService.push_to_peer(peer_id, resource)
				OsrsSkillService.push_to_peer(peer_id, resource)
				push_to_peer(peer_id, resource)
				push_dialogue(peer_id, {
					"npc": str(quest.get("npc_name", "NPC")),
					"text": "Excellent work. Take this pill to aid your breakthrough.",
					"quest_id": String(quest_id),
					"show_accept": false,
					"button_label": "Continue",
					"combat_xp_gained": combat_xp,
					"reward_item_id": reward_item_id,
					"reward_item_name": ItemDatabase.get_name(reward_item_id),
				})
			else:
				push_dialogue(peer_id, {
					"npc": str(quest.get("npc_name", "NPC")),
					"text": "You lack the cores. Return when you have 3.",
					"quest_id": String(quest_id),
					"show_accept": false,
					"button_label": "Continue",
				})
		QuestDatabase.State.COMPLETED:
			push_dialogue(peer_id, {
				"npc": str(quest.get("npc_name", "NPC")),
				"text": "Focus on your cultivation, disciple.",
				"quest_id": String(quest_id),
				"show_accept": false,
				"button_label": "Continue",
			})
		_:
			return {"ok": false, "reason": "invalid_state"}

	return {"ok": true}


static func accept_quest(peer_id: int, resource: PlayerResource, quest_id: StringName) -> Dictionary:
	if resource == null or not QuestDatabase.has_quest(quest_id):
		return {"ok": false, "reason": "unknown_quest"}

	if resource.get_osrs_quest_state(quest_id) != QuestDatabase.State.UNSTARTED:
		return {"ok": false, "reason": "already_started"}

	resource.set_osrs_quest_state(quest_id, QuestDatabase.State.IN_PROGRESS)
	if WorldServer.curr != null:
		WorldServer.curr.database.save_player(resource)
	push_to_peer(peer_id, resource)
	return {"ok": true}


static func _interact_range(npc: Node) -> float:
	if npc.has_method(&"get_interact_range"):
		return float(npc.call(&"get_interact_range"))
	return 90.0
