extends Node
## OSRS-style dialogue quest definitions. Progress is stored per-player as integer
## states in [member PlayerResource.osrs_quests] (0 = unstarted, 1 = in progress, 2 = completed).


enum State {
	UNSTARTED = 0,
	IN_PROGRESS = 1,
	COMPLETED = 2,
}

const THE_ELDERS_REQUEST: StringName = &"the_elders_request"
const SECT_ELDER_NPC: StringName = &"sect_elder"

## quest_id -> definition
const QUESTS: Dictionary = {
	THE_ELDERS_REQUEST: {
		"name": "The Elder's Request",
		"npc_id": SECT_ELDER_NPC,
		"npc_name": "Sect Elder",
		"required_item_id": ItemDatabase.WOLF_CORE,
		"required_amount": 3,
		"combat_xp_reward": 500,
		"reward_item_id": ItemDatabase.IRONBONE_PILL,
		"reward_item_quantity": 1,
	},
}


static func has_quest(quest_id: StringName) -> bool:
	return QUESTS.has(quest_id)


static func get_quest(quest_id: StringName) -> Dictionary:
	return QUESTS.get(quest_id, {}) as Dictionary


static func quest_for_npc(npc_id: StringName) -> StringName:
	for quest_id: StringName in QUESTS:
		var quest: Dictionary = QUESTS[quest_id] as Dictionary
		if quest.get("npc_id", &"") == npc_id:
			return quest_id
	return &""
