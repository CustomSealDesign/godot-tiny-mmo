class_name ItemDatabase
extends RefCounted
## Centralized item definitions for the OSRS-style 28-slot inventory.
## Shared by server and client — lookup by [member item_id] only; no scene resources required.


const SPIRIT_WOOD: int = 9001
const LOW_GRADE_SPIRIT_STONE: int = 9002
const WOLF_CORE: int = 9003
const SPIRIT_COINS: int = 9004
const MINOR_BLOOD_PILL: int = 9005
const IRONBONE_PILL: int = 9006
const IRONWOOD: int = 9007
const BLOODWOOD: int = 9008
const HEAVENLY_ASH: int = 9009
const VOID_TIMBER: int = 9010
const DEMONIC_BEAR_CORE: int = 9011
const WYRM_CORE: int = 9012
const DRAGON_CORE: int = 9013
const VOID_BEAST_CORE: int = 9014
const BLOOD_REFINING_PILL: int = 9015
const HEAVENLY_TRIBULATION_PILL: int = 9016
const VOID_DAO_PILL: int = 9017
const SPIRIT_COPPER_ORE: int = 9018
const METEOR_IRON_ORE: int = 9019
const COPPER_SWORD: int = 9020
const METEOR_IRON_CHESTPLATE: int = 9021

## item_id -> { "name": String, "stackable": bool, "icon": String, "qi_value": int, "equip_slot": String }
const ITEMS: Dictionary = {
	SPIRIT_WOOD: {
		"name": "Spirit Wood",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 5,
		"equip_slot": "",
	},
	LOW_GRADE_SPIRIT_STONE: {
		"name": "Low-Grade Spirit Stone",
		"stackable": true,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	WOLF_CORE: {
		"name": "Wolf Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 50,
	},
	SPIRIT_COINS: {
		"name": "Spirit Coins",
		"stackable": true,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	MINOR_BLOOD_PILL: {
		"name": "Minor Blood Pill",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 200,
	},
	IRONBONE_PILL: {
		"name": "Ironbone Pill",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 1000,
	},
	IRONWOOD: {
		"name": "Ironwood",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 25,
	},
	BLOODWOOD: {
		"name": "Bloodwood",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 100,
	},
	HEAVENLY_ASH: {
		"name": "Heavenly Ash",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 500,
	},
	VOID_TIMBER: {
		"name": "Void Timber",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 2000,
	},
	DEMONIC_BEAR_CORE: {
		"name": "Demonic Bear Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 250,
	},
	WYRM_CORE: {
		"name": "Wyrm Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 1000,
	},
	DRAGON_CORE: {
		"name": "Dragon Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 5000,
	},
	VOID_BEAST_CORE: {
		"name": "Void Beast Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 20000,
	},
	BLOOD_REFINING_PILL: {
		"name": "Blood Refining Pill",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 5000,
	},
	HEAVENLY_TRIBULATION_PILL: {
		"name": "Heavenly Tribulation Pill",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 25000,
	},
	VOID_DAO_PILL: {
		"name": "Void Dao Pill",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 100000,
	},
	SPIRIT_COPPER_ORE: {
		"name": "Spirit Copper Ore",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	METEOR_IRON_ORE: {
		"name": "Meteor Iron Ore",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	COPPER_SWORD: {
		"name": "Copper Sword",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "weapon",
	},
	METEOR_IRON_CHESTPLATE: {
		"name": "Meteor Iron Chestplate",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 0,
		"equip_slot": "chest",
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


static func load_icon(item_id: int) -> Texture2D:
	var path: String = get_icon_path(item_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D
