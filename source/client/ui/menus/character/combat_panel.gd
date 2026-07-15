extends VBoxContainer
## OSRS-style combat options — three stances that train Attack, Strength, or Defense.
## Driven by [code]combat.stance.update[/code] pushes and [code]combat.stance.set[/code] requests.


const STANCES: Array[Dictionary] = [
	{"id": "accurate", "label": "Accurate", "skill": "Attack"},
	{"id": "aggressive", "label": "Aggressive", "skill": "Strength"},
	{"id": "defensive", "label": "Defensive", "skill": "Defense"},
]

@onready var _stance_row: HBoxContainer = %StanceRow

var _stance_buttons: Dictionary = {}


func _ready() -> void:
	_build_stance_buttons()
	ClientState.combat_stance_changed.connect(_refresh_from_state)
	ClientState.local_player_ready.connect(func(_lp: LocalPlayer) -> void:
		_refresh_from_state())
	visibility_changed.connect(_on_visibility_changed)
	_refresh_from_state()


func _on_visibility_changed() -> void:
	if visible:
		_refresh_from_state()


func _build_stance_buttons() -> void:
	for stance: Dictionary in STANCES:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%s\n(%s)" % [stance["label"], stance["skill"]]
		button.custom_minimum_size = Vector2(120, 52)
		var stance_id: String = str(stance["id"])
		button.pressed.connect(_on_stance_pressed.bind(stance_id))
		_stance_row.add_child(button)
		_stance_buttons[stance_id] = button


func _on_stance_pressed(stance_id: String) -> void:
	if ClientState.combat_stance == stance_id:
		_refresh_from_state()
		return
	if InstanceClient.current == null:
		return
	Client.request_data(
		&"combat.stance.set",
		_on_stance_response,
		{"stance": stance_id},
		InstanceClient.current.name,
	)


func _on_stance_response(payload: Variant) -> void:
	if payload is Dictionary:
		var data: Dictionary = payload as Dictionary
		if data.has("combat_stance"):
			ClientState.apply_combat_stance({"combat_stance": data.get("combat_stance")})


func _refresh_from_state() -> void:
	var active: String = ClientState.combat_stance
	for stance_id: String in _stance_buttons:
		var button: Button = _stance_buttons[stance_id] as Button
		button.button_pressed = (stance_id == active)
