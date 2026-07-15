class_name Player3D
extends Character3DClient
## Remote (non-local) player rendered in 3D. The Node2D root still owns the
## authoritative Vector2 :position used by the server; the Body child follows it.


var player_resource: PlayerResource

var active_guild_id: int = 0:
	set = _set_active_guild_id

var teleport_lock_until_ms: int = 0
var pvp_immune_until_ms: int = 0


func _ready() -> void:
	super._ready()
	if not multiplayer.is_server():
		_apply_team_bar_color()


func _set_active_guild_id(value: int) -> void:
	active_guild_id = value
	_apply_team_bar_color()


func _apply_team_bar_color() -> void:
	if multiplayer.is_server():
		return
	var peer: int = name.to_int()
	if Character.spar_opponent_peers.has(peer):
		set_health_bar_fill(BAR_COLOR_HOSTILE)
		return
	if Character.spar_ally_peers.has(peer):
		set_health_bar_fill(BAR_COLOR_ALLY)
		return
	if Character.group_peers.has(peer):
		set_health_bar_fill(BAR_COLOR_ALLY)
		return
	var same_guild: bool = active_guild_id > 0 and active_guild_id == Character.local_viewer_guild_id
	set_health_bar_fill(BAR_COLOR_ALLY if same_guild else BAR_COLOR_HOSTILE)


func mark_just_teleported(cooldown_ms: int = 500) -> void:
	teleport_lock_until_ms = Time.get_ticks_msec() + cooldown_ms


func has_recently_teleported() -> bool:
	return Time.get_ticks_msec() < teleport_lock_until_ms
