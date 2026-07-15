class_name PlayerActivityState
extends RefCounted
## Server-side activity states for OSRS-style gathering loops.


enum State {
	IDLE,
	WOODCUTTING,
	COMBAT,
	ALCHEMY,
}
