class_name ItemDatabase
extends RefCounted
## Centralized item definitions for the OSRS-style 28-slot inventory.
## Shared by server and client — lookup by [member item_id] only; no scene resources required.


# --- Gathering: Woods (Tier 1–5) ---
const SPIRIT_WOOD: int = 9001          # Spirit Bamboo
const IRONWOOD: int = 9007
const BLOODWOOD: int = 9008            # Dragon-blood Timber
const HEAVENLY_ASH: int = 9009
const VOID_TIMBER: int = 9010

# --- Gathering: Monster Cores (Tier 1–5) ---
const WOLF_CORE: int = 9003            # Qi Beast Core
const DEMONIC_BEAR_CORE: int = 9011    # Demonic Core
const WYRM_CORE: int = 9012
const DRAGON_CORE: int = 9013            # True Dragon Core
const VOID_BEAST_CORE: int = 9014

# --- Gathering: Ores / Metals (Tier 1–5) ---
const SPIRIT_COPPER_ORE: int = 9018    # Mortal Copper Ore
const METEOR_IRON_ORE: int = 9019      # Profound Iron Ore
const HEAVENLY_STAR_SILVER_ORE: int = 9022
const AZURE_GOLD_ORE: int = 9023
const CHAOS_VOID_METAL_ORE: int = 9024

# --- Alchemy: Pills (Tier 1–5) ---
const MINOR_BLOOD_PILL: int = 9005     # Marrow Cleansing Pill
const IRONBONE_PILL: int = 9006        # Soul Forging Pill
const BLOOD_REFINING_PILL: int = 9015  # Golden Core Condensing Pill
const HEAVENLY_TRIBULATION_PILL: int = 9016  # Nascent Soul Ascension Pill
const VOID_DAO_PILL: int = 9017        # Tribulation Defying Pill

# --- Forging: Weapons (Tier 1–5) ---
const COPPER_SWORD: int = 9020         # Iron Broadsword
const FROST_SPIRIT_SWORD: int = 9025
const FLYING_FROST_SWORD: int = 9026
const HEAVEN_SPLITTING_SABER: int = 9027
const VOID_ANNIHILATION_BLADE: int = 9028

# --- Forging: Chest Armor (Tier 1–5) ---
const COARSE_CLOTH_ROBE: int = 9029
const METEOR_IRON_CHESTPLATE: int = 9021  # Silk Daoist Robe
const GOLDEN_SILK_ARMOR: int = 9030
const NASCENT_SOUL_ROBE: int = 9031
const TRIBULATION_WARD_ARMOR: int = 9032

# --- Currency & misc ---
const LOW_GRADE_SPIRIT_STONE: int = 9002
const SPIRIT_COINS: int = 9004

## item_id -> { "name": String, "stackable": bool, "icon": String, "qi_value": int, "equip_slot": String }
const ITEMS: Dictionary = {
	# Tier 1 — Qi Condensation Realm (Lv 1–24, Outer Sect)
	SPIRIT_WOOD: {
		"name": "Spirit Bamboo",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 5,
		"equip_slot": "",
	},
	WOLF_CORE: {
		"name": "Qi Beast Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 50,
	},
	SPIRIT_COPPER_ORE: {
		"name": "Mortal Copper Ore",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	MINOR_BLOOD_PILL: {
		"name": "Marrow Cleansing Pill",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 200,
	},
	COPPER_SWORD: {
		"name": "Iron Broadsword",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "weapon",
		"equipment_stats": {"slash_attack": 8, "melee_strength": 6},
	},
	COARSE_CLOTH_ROBE: {
		"name": "Coarse Cloth Robe",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "chest",
		"equipment_stats": {"slash_defense": 8},
	},

	# Tier 2 — Foundation Establishment Realm (Lv 25–49, Inner Sect)
	IRONWOOD: {
		"name": "Ironwood",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 25,
	},
	DEMONIC_BEAR_CORE: {
		"name": "Demonic Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 250,
	},
	METEOR_IRON_ORE: {
		"name": "Profound Iron Ore",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	IRONBONE_PILL: {
		"name": "Soul Forging Pill",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 1000,
	},
	FROST_SPIRIT_SWORD: {
		"name": "Frost Spirit Sword",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "weapon",
		"equipment_stats": {"slash_attack": 22, "melee_strength": 18},
	},
	METEOR_IRON_CHESTPLATE: {
		"name": "Silk Daoist Robe",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "chest",
		"equipment_stats": {"slash_defense": 25},
	},

	# Tier 3 — Golden Core Realm (Lv 50–74, Core Disciple)
	BLOODWOOD: {
		"name": "Dragon-blood Timber",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 100,
	},
	WYRM_CORE: {
		"name": "Golden Core Beast Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 1000,
	},
	HEAVENLY_STAR_SILVER_ORE: {
		"name": "Heavenly Star-silver Ore",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	BLOOD_REFINING_PILL: {
		"name": "Golden Core Condensing Pill",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 5000,
	},
	FLYING_FROST_SWORD: {
		"name": "Flying Frost Sword",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "weapon",
		"equipment_stats": {"slash_attack": 45, "melee_strength": 38},
	},
	GOLDEN_SILK_ARMOR: {
		"name": "Golden Silk Armor",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "chest",
		"equipment_stats": {"slash_defense": 55},
	},

	# Tier 4 — Nascent Soul Realm (Lv 75–89, Sect Elder)
	HEAVENLY_ASH: {
		"name": "Heavenly Ash",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 500,
	},
	DRAGON_CORE: {
		"name": "True Dragon Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 5000,
	},
	AZURE_GOLD_ORE: {
		"name": "Azure Gold Ore",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	HEAVENLY_TRIBULATION_PILL: {
		"name": "Nascent Soul Ascension Pill",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 25000,
	},
	HEAVEN_SPLITTING_SABER: {
		"name": "Heaven-Splitting Saber",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "weapon",
		"equipment_stats": {"slash_attack": 78, "melee_strength": 65},
	},
	NASCENT_SOUL_ROBE: {
		"name": "Nascent Soul Robe",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "chest",
		"equipment_stats": {"slash_defense": 100},
	},

	# Tier 5 — Void Tribulation Realm (Lv 90–99, Patriarch / Ancestor)
	VOID_TIMBER: {
		"name": "Void Timber",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 2000,
	},
	VOID_BEAST_CORE: {
		"name": "Void Sovereign Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 20000,
	},
	CHAOS_VOID_METAL_ORE: {
		"name": "Chaos Void-metal Ore",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	VOID_DAO_PILL: {
		"name": "Tribulation Defying Pill",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 100000,
	},
	VOID_ANNIHILATION_BLADE: {
		"name": "Void Annihilation Blade",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "weapon",
		"equipment_stats": {"slash_attack": 120, "melee_strength": 95},
	},
	TRIBULATION_WARD_ARMOR: {
		"name": "Tribulation Ward Armor",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "chest",
		"equipment_stats": {"slash_defense": 160},
	},

	# Currency & misc
	LOW_GRADE_SPIRIT_STONE: {
		"name": "Low-Grade Spirit Stone",
		"stackable": true,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	SPIRIT_COINS: {
		"name": "Spirit Coins",
		"stackable": true,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
}


static func has_item(item_id: int) -> bool:
	return ITEMS.has(item_id)


static func get_name(item_id: int) -> String:
	return str(ITEMS.get(item_id, {}).get("name", "Unknown"))


static func is_stackable(item_id: int) -> bool:
	return bool(ITEMS.get(item_id, {}).get("stackable", false))


static func get_qi_value(item_id: int) -> int:
	return int(ITEMS.get(item_id, {}).get("qi_value", 0))


static func is_consumable(item_id: int) -> bool:
	return get_qi_value(item_id) > 0


static func get_icon_path(item_id: int) -> String:
	return str(ITEMS.get(item_id, {}).get("icon", ""))


static func get_equip_slot(item_id: int) -> String:
	return str(ITEMS.get(item_id, {}).get("equip_slot", ""))


static func is_equippable(item_id: int) -> bool:
	return not get_equip_slot(item_id).is_empty()


static func get_equipment_stats(item_id: int) -> Dictionary:
	var stats_v: Variant = ITEMS.get(item_id, {}).get("equipment_stats", {})
	if stats_v is Dictionary:
		return stats_v as Dictionary
	return {}


static func get_equipment_stat(item_id: int, stat_key: String) -> int:
	return int(get_equipment_stats(item_id).get(stat_key, 0))


static func load_icon(item_id: int) -> Texture2D:
	var path: String = get_icon_path(item_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D


# =============================================================================
# ENEMY STAT TEMPLATES — Recommended export values for tiered cultivation beasts.
# Copy these onto Enemy scene nodes when authoring world spawns.
# Fields match [Enemy]: max_hp, defense_level, defense_bonus, attack_damage, loot.
# =============================================================================
#
# Tier 1 — Qi Condensation Realm (Lv 1–24, Outer Sect)
#   display_name: "Qi Condensation Serpent"
#   max_hp: 30
#   defense_level: 5
#   defense_bonus: 0
#   attack_damage: 6
#   loot_item_id: ItemDatabase.WOLF_CORE          # Qi Beast Core
#   loot_quantity: 1
#
# Tier 2 — Foundation Establishment Realm (Lv 25–49, Inner Sect)
#   display_name: "Foundation Demon"
#   max_hp: 90
#   defense_level: 35
#   defense_bonus: 8
#   attack_damage: 14
#   loot_item_id: ItemDatabase.DEMONIC_BEAR_CORE   # Demonic Core
#   loot_quantity: 1
#
# Tier 3 — Golden Core Realm (Lv 50–74, Core Disciple)
#   display_name: "Golden Core Chimaera"
#   max_hp: 280
#   defense_level: 62
#   defense_bonus: 18
#   attack_damage: 32
#   loot_item_id: ItemDatabase.WYRM_CORE             # Golden Core Beast Core
#   loot_quantity: 1
#
# Tier 4 — Nascent Soul Realm (Lv 75–89, Sect Elder)
#   display_name: "Nascent Soul Fiend"
#   max_hp: 650
#   defense_level: 82
#   defense_bonus: 35
#   attack_damage: 58
#   loot_item_id: ItemDatabase.DRAGON_CORE          # True Dragon Core
#   loot_quantity: 1
#
# Tier 5 — Void Tribulation Realm (Lv 90–99, Patriarch / Ancestor)
#   display_name: "Void Tribulation Beast"
#   max_hp: 1600
#   defense_level: 96
#   defense_bonus: 55
#   attack_damage: 95
#   loot_item_id: ItemDatabase.VOID_BEAST_CORE       # Void Sovereign Core
#   loot_quantity: 1
#
# Starter reference — Spirit Wolf (Outer Sect tutorial mob):
#   display_name: "Spirit Wolf"
#   max_hp: 20
#   defense_level: 2
#   defense_bonus: 0
#   attack_damage: 5
#   loot_item_id: ItemDatabase.WOLF_CORE
#   loot_quantity: 1
