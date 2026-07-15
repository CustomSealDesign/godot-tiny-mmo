class_name CultivationHud
extends PanelContainer
## Top-left HUD strip for Xianxia cultivation state and woodcutting XP.
## Driven by [code]cultivation.update[/code] pushes and [code]cultivation.get[/code] pulls.


var _qi_label: Label
var _realm_label: Label
var _woodcutting_label: Label


func _ready() -> void:
	_build_ui()
	ClientState.cultivation_changed.connect(_refresh_from_state)
	ClientState.local_player_ready.connect(func(_lp: LocalPlayer) -> void:
		_refresh_cultivation())
	_refresh_from_state()


func _refresh_cultivation() -> void:
	if InstanceClient.current == null:
		return
	Client.request_data(&"cultivation.get", ClientState.apply_cultivation, {}, InstanceClient.current.name)


func _refresh_from_state() -> void:
	_qi_label.text = "Qi: %d" % ClientState.qi_level
	_realm_label.text = "Realm: %s" % ClientState.cultivation_realm
	_woodcutting_label.text = "Woodcutting XP: %d" % ClientState.woodcutting_xp


func _build_ui() -> void:
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 10.0
	offset_top = 48.0
	offset_right = 220.0
	offset_bottom = 118.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.06, 0.08, 0.55)
	panel.set_corner_radius_all(8)
	panel.content_margin_top = 6
	panel.content_margin_bottom = 6
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	add_theme_stylebox_override(&"panel", panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_qi_label = Label.new()
	_qi_label.add_theme_font_size_override(&"font_size", 13)
	_qi_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_qi_label)

	_realm_label = Label.new()
	_realm_label.add_theme_font_size_override(&"font_size", 13)
	_realm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_realm_label)

	_woodcutting_label = Label.new()
	_woodcutting_label.add_theme_font_size_override(&"font_size", 13)
	_woodcutting_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_woodcutting_label)
