extends Control

class_name StrikeIndicator

## Compact, text-free three-strike readout for the gameplay HUD.

@export var max_strikes := 3
@export var filled_color := Color("#ff6575")
@export var empty_color := Color(0.38, 0.43, 0.61, 0.72)
@export var outline_color := Color(1.0, 0.88, 0.72, 0.78)
@export var strike_spacing := 28.0
@export var strike_radius := 8.0

var strikes := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	queue_redraw()


func set_strikes(value: int) -> void:
	strikes = clampi(value, 0, maxi(max_strikes, 0))
	queue_redraw()


func get_remaining_strikes() -> int:
	return maxi(max_strikes - strikes, 0)


func _draw() -> void:
	var count := maxi(max_strikes, 0)
	var origin := Vector2(strike_radius, strike_radius)
	for index in count:
		var center := origin + Vector2(strike_spacing * index, 0.0)
		var color := filled_color if index >= strikes else empty_color
		draw_circle(center, strike_radius, color)
		draw_arc(center, strike_radius, 0.0, TAU, 16, outline_color, 1.5, true)
