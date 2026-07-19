class_name PixelScale3D
extends RefCounted
## Single source of truth for the "pixel-scale 3D" rendering convention.
##
## The server plane (Vector2) is authored in PIXELS; the client renders those
## pixels 1:1 as world units (see [PlaneCoords3D] — plane X/Y map straight to
## world X/Z). Everything visual — sprite billboards, camera zoom, the tile
## floor — derives from the constants here so the look stays consistent and any
## future scale/offset tweak happens in exactly ONE place. Before this file the
## same numbers were duplicated across scenes and drifted, which is what the
## recent "vertical offset" fix-up commits were chasing.


## World units per authored plane pixel. The plane->world map is 1:1, so 1.0.
## Kept explicit so the whole convention reads from one file.
const WORLD_UNITS_PER_PIXEL: float = 1.0

## Tile edge length in world units. MUST stay in sync with
## [constant GridMovement.TILE_SIZE] (32 px/tile). Duplicated (not referenced)
## to keep this a leaf utility with no load-order coupling to movement code.
const TILE_WORLD_SIZE: float = 32.0

## [member Sprite3D.pixel_size] for character/prop billboards. Source art is
## authored at ~4x the tile pixel density (a ~512 px sprite frame reads as a
## 2-tile-tall character), so 1 texture pixel = 0.125 world units.
const SPRITE_PIXEL_SIZE: float = 0.125

## Orthographic [member Camera3D.size]: world units (pixels) the view spans
## vertically. 384 = 12 tiles.
const CAMERA_ORTHO_SIZE: float = 384.0


## Local Y (world units) at which to place a centered billboard so its BOTTOM
## edge sits on the floor plane (feet on the ground, not clipping or hovering).
## Derived from the sprite's real frame height, so it is correct for a sprite of
## ANY size — a 1-tile mob and a 2-tile boss both land right. Replaces the old
## hardcoded per-scene Y offset that only fit one sprite height.
static func ground_offset_for(sprite: Sprite3D) -> float:
	if sprite == null or sprite.texture == null:
		return TILE_WORLD_SIZE
	var frame_height_px: float = float(sprite.texture.get_height()) / float(maxi(1, sprite.vframes))
	return frame_height_px * sprite.pixel_size * 0.5


## Apply the canonical billboard scale + ground offset to a Sprite3D in one call.
## Client-only callers use this from _ready so every entity is placed identically.
static func apply_billboard(sprite: Sprite3D) -> void:
	if sprite == null:
		return
	sprite.pixel_size = SPRITE_PIXEL_SIZE
	sprite.position.y = ground_offset_for(sprite)
