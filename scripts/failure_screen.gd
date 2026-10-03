extends Control

class_name FailureScreen

signal retry_requested

@onready var game_over: GameOver = $GameOver
@onready var transition: FailureTransition = $FailureTransition


func _ready() -> void:
	game_over.retry_pressed.connect(func() -> void: retry_requested.emit())


func show_failure(image: Image, duration: float, rotation_radians: float) -> void:
	game_over.show_standalone_card()
	transition.play_snapshot(image, duration, rotation_radians)
