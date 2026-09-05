@tool
extends Sprite2D

class_name DepthTaggedSprite2D

## A normal Sprite2D with the metadata used by the depth baker.
##
## Depth values are normalized by the baker into the red channel.  Zero is the
## shallowest section, so it receives the highest render priority.

@export_range(0.0, 1000.0, 0.01) var depth := 0.0:
	set(value):
		depth = value
		_apply_render_order()
@export var contributes_to_bounds := true
@export var participates_in_occlusion := true:
	set(value):
		participates_in_occlusion = value
		_apply_render_order()
@export var participates_in_render_order := true:
	set(value):
		participates_in_render_order = value
		_apply_render_order()
@export var render_band_count := 4
@export var render_base_z_index := 0
@export var render_band_step := 10


func _ready() -> void:
	_apply_render_order()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_apply_render_order()


func get_depth() -> float:
	return depth


func get_depth_band() -> int:
	var safe_count := maxi(render_band_count, 1)
	return mini(safe_count - 1, maxi(0, floori(clampf(depth, 0.0, 0.999999) * safe_count)))


func _apply_render_order() -> void:
	if not participates_in_occlusion or not participates_in_render_order:
		z_index = render_base_z_index
		return
	var band := get_depth_band()
	z_index = render_base_z_index + (maxi(render_band_count, 1) - 1 - band) * render_band_step
