extends VBoxContainer
## OSRS-style skills panel — shows level (derived from XP) for Spirit_Gathering,
## Alchemy, and Combat. Driven by [code]skills.update[/code] pushes and
## [code]skills.osrs.get[/code] pulls.


const SKILL_LABELS: Dictionary = {
	"Spirit_Gathering": "Spirit Gathering",
	"Alchemy": "Alchemy",
	"Combat": "Combat",
	"Mining": "Spirit Mining",
	"Forging": "Spirit Forging",
	"Attack": "Sword Arts",
	"Strength": "Body Cultivation",
	"Defense": "Iron Body",
	"Hitpoints": "Vitality",
}

const SKILL_ICONS: Dictionary = {
	"Spirit_Gathering": preload("res://assets/ui/skills/skill_spirit_gathering.svg"),
	"Mining": preload("res://assets/ui/skills/skill_mining.svg"),
	"Forging": preload("res://assets/ui/skills/skill_forging.svg"),
	"Alchemy": preload("res://assets/ui/skills/skill_alchemy.svg"),
	"Attack": preload("res://assets/ui/skills/skill_attack.svg"),
	"Strength": preload("res://assets/ui/skills/skill_strength.svg"),
	"Defense": preload("res://assets/ui/skills/skill_defense.svg"),
	"Hitpoints": preload("res://assets/ui/skills/skill_hitpoints.svg"),
	"Combat": preload("res://assets/ui/skills/skill_attack.svg"),
}

const SKILL_ICON_SIZE: Vector2 = Vector2(28, 28)

@onready var _skill_list: VBoxContainer = %OsrsSkillList


func _ready() -> void:
	_add_title_if_needed()
	ClientState.skills_changed.connect(_refresh_from_state)
	ClientState.local_player_ready.connect(func(_lp: LocalPlayer) -> void:
		_fetch_skills())
	visibility_changed.connect(_on_visibility_changed)
	_refresh_from_state()


func _on_visibility_changed() -> void:
	if visible:
		_fetch_skills()


func _fetch_skills() -> void:
	if InstanceClient.current == null:
		return
	Client.request_data(&"skills.osrs.get", apply_skills_payload, {}, InstanceClient.current.name)


func apply_skills_payload(payload: Variant) -> void:
	if payload is Dictionary:
		ClientState.apply_skills(payload as Dictionary)


func _add_title_if_needed() -> void:
	if get_child_count() > 1:
		return
	var title: Label = Label.new()
	title.text = "Skills"
	title.add_theme_font_size_override(&"font_size", 16)
	title.add_theme_color_override(&"font_color", Color(1, 0.9, 0.55))
	add_child(title)
	move_child(title, 0)


func _refresh_from_state() -> void:
	for child: Node in _skill_list.get_children():
		child.queue_free()

	for skill_key: String in [
		"Spirit_Gathering",
		"Mining",
		"Forging",
		"Alchemy",
		"Attack",
		"Strength",
		"Defense",
		"Hitpoints",
		"Combat",
	]:
		var entry: Dictionary = ClientState.osrs_skills.get(skill_key, {}) as Dictionary
		var xp: int = int(entry.get("xp", 0))
		var level: int = int(entry.get("level", SkillManager.get_level_from_xp(xp)))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		_skill_list.add_child(row)

		var icon_texture: Texture2D = SKILL_ICONS.get(skill_key, null) as Texture2D
		if icon_texture != null:
			var icon: TextureRect = TextureRect.new()
			icon.custom_minimum_size = SKILL_ICON_SIZE
			icon.texture = icon_texture
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			row.add_child(icon)

		var name_label: Label = Label.new()
		name_label.text = SKILL_LABELS.get(skill_key, skill_key)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override(&"font_size", 14)
		row.add_child(name_label)

		var level_label: Label = Label.new()
		level_label.text = "Lv %d" % level
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		level_label.add_theme_font_size_override(&"font_size", 14)
		row.add_child(level_label)

		var xp_label: Label = Label.new()
		xp_label.text = "%s XP" % _format_xp(xp)
		xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		xp_label.add_theme_font_size_override(&"font_size", 12)
		xp_label.add_theme_color_override(&"font_color", Color(0.75, 0.75, 0.8))
		row.add_child(xp_label)


static func _format_xp(xp: int) -> String:
	var text: String = str(maxi(0, xp))
	if text.length() <= 3:
		return text
	var parts: PackedStringArray = PackedStringArray()
	while text.length() > 3:
		parts.insert(0, text.substr(text.length() - 3, 3))
		text = text.substr(0, text.length() - 3)
	if not text.is_empty():
		parts.insert(0, text)
	return ",".join(parts)
