@tool
extends Node2D

class_name PissToilet

## Shared layout contract for the toilet artwork.
##
## The scene's root transform is deliberately left to its owner. A level can
## place and scale the whole toilet for its composition, while this node keeps
## the bowl, seat, tank, and floor opening in the same local coordinate space.

signal layout_changed

const DEFAULT_ALPHA_THRESHOLD := SurfaceEffects.DEFAULT_ALPHA_THRESHOLD
const REFERENCE_VIEWPORT := Vector2(720.0, 1280.0)

## The child transforms in piss_toilet.tscn are authored artwork. These
## read-only properties expose the authored layout to dependent systems, but
## apply_layout never rewrites those child transforms.
var bowl_art_scale: float:
	get:
		return _bowl.scale.x if is_instance_valid(_bowl) else 0.75

var bowl_assembly_offset: Vector2:
	get:
		return _bowl.position if is_instance_valid(_bowl) else Vector2.ZERO

var bowl_offset: Vector2:
	get:
		return bowl_assembly_offset

var seat_offset: Vector2:
	get:
		if not is_instance_valid(_seat) or not is_instance_valid(_bowl):
			return Vector2.ZERO
		return _seat.position - _bowl.position

var outer_shadow_offset: Vector2:
	get:
		if not is_instance_valid(_outside) or not is_instance_valid(_bowl):
			return Vector2.ZERO
		return _outside.position - _bowl.position

var tank_anchor: Vector2:
	get:
		return _tank.position if is_instance_valid(_tank) else Vector2.ZERO

var tank_scale: Vector2:
	get:
		return _tank.scale if is_instance_valid(_tank) else Vector2.ONE
@export_range(0.0, 1.0, 0.005) var alpha_threshold := DEFAULT_ALPHA_THRESHOLD

## This is the existing Level 1 opening, expressed as offsets from the bowl
## anchor in toilet-local coordinates. It is intentionally larger than the
## visible bowl so the entire opening remains neutral while the surrounding
## floor remains a strike area.
@export var floor_exclusion_offsets := PackedVector2Array(
	[
		Vector2(0.0, -446.925),
		Vector2(178.2, -429.645),
		Vector2(307.8, -349.005),
		Vector2(381.24, -191.565),
		Vector2(397.44, 38.835),
		Vector2(372.6, 255.795),
		Vector2(275.4, 384.435),
		Vector2(145.8, 428.595),
		Vector2(0.0, 434.355),
		Vector2(-153.36, 428.595),
		Vector2(-275.4, 370.995),
		Vector2(-356.4, 240.435),
		Vector2(-388.8, 38.835),
		Vector2(-380.16, -191.565),
		Vector2(-315.36, -349.005),
		Vector2(-185.76, -429.645),
	],
)

var _layout_signature := ""
var _has_applied_layout := false
var _viewport_signature := Vector2.ZERO

@onready var _outside: Sprite2D = $Outside
@onready var _bowl: Sprite2D = $Bowl
@onready var _tank: Sprite2D = $Tank
@onready var _seat: Sprite2D = $Seat


func _ready() -> void:
	apply_layout()


func _process(_delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size == _viewport_signature:
		return
	_viewport_signature = viewport_size
	apply_layout()


func apply_layout() -> void:
	## Apply only child layout. The root position and scale belong to the owner.
	## Repeated calls are safe and do not touch any gameplay state.
	_resolve_parts()
	if (
			not is_instance_valid(_outside)
			or not is_instance_valid(_bowl)
			or not is_instance_valid(_tank)
			or not is_instance_valid(_seat)
	):
		return

	var previous_signature := _layout_signature
	# Do not assign any child position or scale here. These are intentionally
	# scene-authored so edits to piss_toilet.tscn survive layout and resize
	# updates. Dependent systems read the resulting transforms below.

	_layout_signature = _make_layout_signature()
	if not _has_applied_layout or previous_signature != _layout_signature:
		_has_applied_layout = true
		layout_changed.emit()


func get_bowl_anchor_global() -> Vector2:
	apply_layout()
	return _bowl.global_position


func to_viewport_normalized(
		local_points: PackedVector2Array,
		viewport_size: Vector2,
) -> PackedVector2Array:
	var safe_viewport_size := _safe_viewport_size(viewport_size)
	var normalized := PackedVector2Array()
	for local_point in local_points:
		normalized.append(to_global(local_point) / safe_viewport_size)
	return normalized


func get_floor_exclusion_normalized(viewport_size: Vector2) -> PackedVector2Array:
	apply_layout()
	var local_points := PackedVector2Array()
	for offset in floor_exclusion_offsets:
		local_points.append(_bowl.position + offset)
	return to_viewport_normalized(local_points, viewport_size)


func get_floor_exclusion_local_points() -> PackedVector2Array:
	apply_layout()
	var local_points := PackedVector2Array()
	for offset in floor_exclusion_offsets:
		local_points.append(_bowl.position + offset)
	return local_points


func get_bowl_anchor_local() -> Vector2:
	apply_layout()
	return _bowl.position


func get_bowl_art_scale() -> float:
	apply_layout()
	return _bowl.scale.x


func _resolve_parts() -> void:
	if not is_instance_valid(_outside):
		_outside = get_node_or_null("Outside") as Sprite2D
	if not is_instance_valid(_bowl):
		_bowl = get_node_or_null("Bowl") as Sprite2D
	if not is_instance_valid(_tank):
		_tank = get_node_or_null("Tank") as Sprite2D
	if not is_instance_valid(_seat):
		_seat = get_node_or_null("Seat") as Sprite2D


func _safe_viewport_size(viewport_size: Vector2) -> Vector2:
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return REFERENCE_VIEWPORT
	return viewport_size


func _make_layout_signature() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		position,
		scale,
		rotation,
		skew,
		_outside.position,
		_outside.scale,
		_bowl.position,
		_bowl.scale,
		_tank.position,
		_tank.scale,
		_seat.position,
		_seat.scale,
		alpha_threshold,
		floor_exclusion_offsets,
		get_viewport().get_visible_rect().size,
	]
