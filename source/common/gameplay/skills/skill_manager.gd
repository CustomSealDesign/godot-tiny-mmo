extends Node
## OSRS-style skill XP curve shared by server and client.
## Level is always derived from total XP via [method get_level_from_xp].


const MAX_LEVEL: int = 99
const XP_LEVEL_99: int = 13_034_431

const SPIRIT_GATHERING: StringName = &"Spirit_Gathering"
const ALCHEMY: StringName = &"Alchemy"
const COMBAT: StringName = &"Combat"
const MINING: StringName = &"Mining"
const FORGING: StringName = &"Forging"

const STARTING_SKILLS: Array[StringName] = [
	SPIRIT_GATHERING,
	ALCHEMY,
	COMBAT,
	MINING,
	FORGING,
]

## Precomputed total XP required to reach each level (index = level, value = xp).
static var _xp_for_level: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_ensure_lookup()


static func _ensure_lookup() -> void:
	if not _xp_for_level.is_empty():
		return
	_xp_for_level.resize(MAX_LEVEL + 1)
	for level: int in range(1, MAX_LEVEL + 1):
		_xp_for_level[level] = _compute_xp_for_level(level)


## Total XP required to be level [param level] (level 1 = 0 XP).
static func xp_for_level(level: int) -> int:
	_ensure_lookup()
	var clamped: int = clampi(level, 1, MAX_LEVEL)
	return _xp_for_level[clamped]


static func _compute_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	var points: float = 0.0
	for l: int in range(1, level):
		points += floorf(float(l) + 300.0 * pow(2.0, float(l) / 7.0))
	return int(floorf(points / 4.0))


## Returns the skill level for [param xp] total experience (1–99).
static func get_level_from_xp(xp: int) -> int:
	_ensure_lookup()
	var safe_xp: int = maxi(0, xp)
	var level: int = 1
	while level < MAX_LEVEL and safe_xp >= _xp_for_level[level + 1]:
		level += 1
	return level


## XP still needed to reach [param level] from [param xp].
static func xp_to_next_level(xp: int) -> int:
	var level: int = get_level_from_xp(xp)
	if level >= MAX_LEVEL:
		return 0
	return maxi(0, xp_for_level(level + 1) - xp)
