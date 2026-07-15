extends Node
## OSRS-style dialogue quest definitions. Progress is stored per-player as integer
## states in [member PlayerResource.osrs_quests] (0 = unstarted, 1 = in progress, 2 = completed).


enum State {
	UNSTARTED = 0,
	IN_PROGRESS = 1,
	COMPLETED = 2,
}

# --- Quest IDs ---
const THE_ELDERS_REQUEST: StringName = &"the_elders_request"
const INNER_SECT_TRIAL: StringName = &"inner_sect_trial"
const THE_GOLDEN_CORE_BOTTLENECK: StringName = &"the_golden_core_bottleneck"
const NASCENT_SOUL_AUDIT: StringName = &"nascent_soul_audit"
const VOID_TRIBULATION_OATH: StringName = &"void_tribulation_oath"

# --- NPC IDs (one unique npc_id per quest for [method quest_for_npc]) ---
const SECT_ELDER_NPC: StringName = &"sect_elder"
const INNER_SECT_WARDEN_NPC: StringName = &"inner_sect_warden"
const CORE_PAVILION_MASTER_NPC: StringName = &"core_pavilion_master"
const ELDER_COUNCIL_NPC: StringName = &"elder_council"
const PATRIARCH_ANCESTOR_NPC: StringName = &"patriarch_ancestor"

## quest_id -> definition
const QUESTS: Dictionary = {
	# Tier 1 — Qi Condensation Realm (Outer Sect)
	THE_ELDERS_REQUEST: {
		"name": "The Elder's Request",
		"npc_id": SECT_ELDER_NPC,
		"npc_name": "Sect Elder",
		"required_item_id": ItemDatabase.WOLF_CORE,
		"required_amount": 3,
		"combat_xp_reward": 800,
		"reward_item_id": ItemDatabase.MINOR_BLOOD_PILL,
		"reward_item_quantity": 1,
	},

	# Tier 2 — Foundation Establishment Realm (Inner Sect)
	INNER_SECT_TRIAL: {
		"name": "Inner Sect Trial",
		"npc_id": INNER_SECT_WARDEN_NPC,
		"npc_name": "Inner Sect Warden",
		"required_item_id": ItemDatabase.METEOR_IRON_ORE,
		"required_amount": 5,
		"combat_xp_reward": 8000,
		"reward_item_id": ItemDatabase.METEOR_IRON_CHESTPLATE,
		"reward_item_quantity": 1,
	},

	# Tier 3 — Golden Core Realm (Core Disciple)
	THE_GOLDEN_CORE_BOTTLENECK: {
		"name": "The Golden Core Bottleneck",
		"npc_id": CORE_PAVILION_MASTER_NPC,
		"npc_name": "Core Pavilion Master",
		"required_item_id": ItemDatabase.IRONBONE_PILL,
		"required_amount": 1,
		"combat_xp_reward": 50000,
		"reward_item_id": ItemDatabase.FLYING_FROST_SWORD,
		"reward_item_quantity": 1,
	},

	# Tier 4 — Nascent Soul Realm (Sect Elder)
	NASCENT_SOUL_AUDIT: {
		"name": "Nascent Soul Audit",
		"npc_id": ELDER_COUNCIL_NPC,
		"npc_name": "Elder Council Speaker",
		"required_item_id": ItemDatabase.HEAVENLY_TRIBULATION_PILL,
		"required_amount": 1,
		"combat_xp_reward": 200000,
		"reward_item_id": ItemDatabase.HEAVEN_SPLITTING_SABER,
		"reward_item_quantity": 1,
	},

	# Tier 5 — Void Tribulation Realm (Patriarch / Ancestor)
	VOID_TRIBULATION_OATH: {
		"name": "Void Tribulation Oath",
		"npc_id": PATRIARCH_ANCESTOR_NPC,
		"npc_name": "Sect Patriarch",
		"required_item_id": ItemDatabase.VOID_DAO_PILL,
		"required_amount": 1,
		"combat_xp_reward": 500000,
		"reward_item_id": ItemDatabase.VOID_ANNIHILATION_BLADE,
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
