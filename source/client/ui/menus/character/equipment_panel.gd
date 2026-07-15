extends VBoxContainer
## OSRS-style equipment panel — four gear slots (Head, Chest, Legs, Weapon).
## Driven by [code]equipment.update[/code] pushes and [code]equipment.get[/code] pulls.


const SLOT_LABELS: Dictionary = {
	"head": "Head",
	"chest": "Chest",
	"legs": "Legs",
	"weapon": "Weapon",
}

const SLOT_SIZE: Vector2 = Vector2(56, 56)

@onready var _slot_grid: GridContainer = %EquipmentSlotGrid


func _ready() -> void:
	_add_title_if_needed()
	_build_slots()
	ClientState.equipment_changed.connect(_refresh_from_state)
	ClientState.local_player_ready.connect(func(_lp: LocalPlayer) -> void:
		_fetch_equipment())
	visibility_changed.connect(_on_visibility_changed)
	_refresh_from_state()


func _on_visibility_changed() -> void:
	if visible:
		_fetch_equipment()


func _fetch_equipment() -> void:
	if InstanceClient.current == null:
		return
	Client.request_data(&"equipment.get", apply_equipment_payload, {}, InstanceClient.current.name)


func apply_equipment_payload(payload: Variant) -> void:
	if payload is Dictionary:
		ClientState.apply_equipment(payload as Dictionary)


func _add_title_if_needed() -> void:
	if get_child_count() > 1:
		return
	var title: Label = Label.new()
	title.text = "Equipment"
	title.add_theme_font_size_override(&"font_size", 16)
	title.add_theme_color_override(&"font_color", Color(1, 0.9, 0.55))
	add_child(title)
	move_child(title, 0)


func _build_slots() -> void:
	for slot_key: String in ["head", "chest", "legs", "weapon"]:
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 4)
		_slot_grid.add_child(column)

		var label: Label = Label.new()
		label.text = SLOT_LABELS.get(slot_key, slot_key.capitalize())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", 12)
		column.add_child(label)

		var button: Button = Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.clip_contents = true
		button.focus_mode = Control.FOCUS_NONE
		button.name = slot_key
		button.gui_input.connect(_on_slot_gui_input.bind(slot_key))
		column.add_child(button)


func _refresh_from_state() -> void:
	for column: Node in _slot_grid.get_children():
		if not (column is VBoxContainer):
			continue
		for child: Node in column.get_children():
			if not (child is Button):
				continue
			var slot_key: String = child.name
			_clear_slot_button(child as Button)
			var item_id: int = int(ClientState.equipment.get(slot_key, 0))
			if item_id <= 0:
				continue
			var icon: Texture2D = ItemDatabase.load_icon(item_id)
			if icon != null:
				PixelIcon.set_art(child as Button, icon)
			(child as Button).tooltip_text = ItemDatabase.get_name(item_id)


func _on_slot_gui_input(event: InputEvent, slot_key: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var item_id: int = int(ClientState.equipment.get(slot_key, 0))
	if item_id <= 0:
		return
	_try_unequip(slot_key)


func _try_unequip(slot_key: String) -> void:
	if InstanceClient.current == null:
		return
	Client.request_data(
		&"unequip_item",
		_on_unequip_response,
		{"slot": slot_key},
		InstanceClient.current.name,
	)


func _on_unequip_response(payload: Variant) -> void:
	if not (payload is Dictionary):
		return
	var data: Dictionary = payload as Dictionary
	if not bool(data.get("ok", false)):
		return
	if data.has("slots"):
		ClientState.apply_inventory({"slots": data.get("slots", [])})
	if data.has("equipment"):
		ClientState.apply_equipment({"equipment": data.get("equipment", {})})


func _clear_slot_button(button: Button) -> void:
	PixelIcon.set_art(button, null)
	button.tooltip_text = ""
