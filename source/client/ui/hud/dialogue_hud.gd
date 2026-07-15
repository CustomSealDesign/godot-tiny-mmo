class_name DialogueHud
extends Control
## Bottom dialogue box for OSRS-style NPC quest lines. Driven by server [code]dialogue.push[/code].


const BUTTON_HEIGHT: float = 46.0
const SCROLL_TEXTURE: Texture2D = preload("res://assets/ui/menus/ui_dialogue_scroll.svg")
const SCROLL_MARGIN_LEFT: int = 72
const SCROLL_MARGIN_RIGHT: int = 72
const SCROLL_MARGIN_TOP: int = 28
const SCROLL_MARGIN_BOTTOM: int = 24

var _box: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _action_button: Button
var _current: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	Client.subscribe(&"dialogue.push", _on_dialogue_push)


func _on_dialogue_push(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	_current = payload
	_rebuild()
	show()


func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()

	_box = PanelContainer.new()
	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 40.0
	_box.offset_right = -40.0
	_box.offset_top = -148.0
	_box.offset_bottom = -28.0
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var scroll_style: StyleBoxTexture = StyleBoxTexture.new()
	scroll_style.texture = SCROLL_TEXTURE
	scroll_style.texture_margin_left = SCROLL_MARGIN_LEFT
	scroll_style.texture_margin_right = SCROLL_MARGIN_RIGHT
	scroll_style.texture_margin_top = SCROLL_MARGIN_TOP
	scroll_style.texture_margin_bottom = SCROLL_MARGIN_BOTTOM
	_box.add_theme_stylebox_override(&"panel", scroll_style)
	add_child(_box)

	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override(&"margin_left", SCROLL_MARGIN_LEFT)
	pad.add_theme_constant_override(&"margin_right", SCROLL_MARGIN_RIGHT)
	pad.add_theme_constant_override(&"margin_top", SCROLL_MARGIN_TOP)
	pad.add_theme_constant_override(&"margin_bottom", SCROLL_MARGIN_BOTTOM)
	_box.add_child(pad)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 8)
	pad.add_child(vbox)

	_name_label = Label.new()
	_name_label.text = str(_current.get("npc", "NPC"))
	_name_label.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.6))
	_name_label.add_theme_font_size_override(&"font_size", 16)
	vbox.add_child(_name_label)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.fit_content = true
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.text = str(_current.get("text", ""))
	vbox.add_child(_text)

	_action_button = Button.new()
	_action_button.text = str(_current.get("button_label", "Continue"))
	_action_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_action_button.pressed.connect(_on_action_pressed)
	vbox.add_child(_action_button)

	_fit_box.call_deferred()


func _on_action_pressed() -> void:
	if bool(_current.get("show_accept", false)):
		var quest_id: String = str(_current.get("quest_id", ""))
		if not quest_id.is_empty() and InstanceClient.current != null:
			Client.request_data(
				&"quest.osrs.accept",
				Callable(),
				{"quest": quest_id},
				InstanceClient.current.name
			)
	else:
		var combat_xp: int = int(_current.get("combat_xp_gained", 0))
		if combat_xp > 0:
			var lines: PackedStringArray = PackedStringArray()
			lines.append("+%d Combat XP" % combat_xp)
			var reward_name: String = str(_current.get("reward_item_name", ""))
			if not reward_name.is_empty():
				lines.append("Received %s" % reward_name)
			Toaster.toast_group("Quest Complete", lines)
	hide()
	_current = {}


func _fit_box() -> void:
	if _box == null or _text == null:
		return
	var content_h: float = _text.get_content_height()
	var needed: float = 22.0 + 8.0 + content_h + BUTTON_HEIGHT + 8.0 + 24.0
	_box.offset_top = _box.offset_bottom - maxf(needed, 120.0)
