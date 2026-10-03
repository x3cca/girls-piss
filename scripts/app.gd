extends Control

class_name App

const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")
const RESULTS_SCREEN_SCENE: PackedScene = preload("res://scenes/results_screen.tscn")
const FAILURE_SCREEN_SCENE: PackedScene = preload("res://scenes/failure_screen.tscn")
const ROOM_BACKDROP_SCENE: PackedScene = preload("res://scenes/level_1_background.tscn")
const TOILET_SCENE: PackedScene = preload("res://scenes/piss_toilet.tscn")
const CREDITS_SCENE_PATH := "res://scenes/credits.tscn"

const SOURCE_KEYBOARD := 0
const SOURCE_MOUSE := 1
const SOURCE_TOUCH := 2
const SOURCE_CONTROLLER := 3

@export var level_definitions: Array[LevelDefinition] = [
	preload("res://resources/level_1_definition.tres"),
]

@onready var _backdrop_world: Node2D = $BackdropWorld
@onready var _menu_music: AudioStreamPlayer = GameAudio.create_player($MenuMusic, self)

var _active_screen: Node
var _title_screen: TitleScreen
var _main_menu: Control
var _results_screen: Control
var _active_level: Node
var _last_input_source := SOURCE_KEYBOARD
var _current_level_id: StringName = &"level_1"
var _attempt_generation := 0
var _route_pending := false


func _ready() -> void:
	var room_stream := _menu_music.stream as AudioStreamOggVorbis
	if room_stream:
		room_stream.loop = true
	_add_presentation_backdrop()
	_show_title()


func _exit_tree() -> void:
	GameAudio.reset_music()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_title_screen) or not _title_screen.is_active():
		return
	var source := _source_for_start_event(event)
	if source < SOURCE_KEYBOARD:
		return
	_last_input_source = source
	get_viewport().set_input_as_handled()
	_title_screen.request_start(source)


func _add_presentation_backdrop() -> void:
	var room := ROOM_BACKDROP_SCENE.instantiate()
	_backdrop_world.add_child(room)
	var toilet := TOILET_SCENE.instantiate()
	toilet.position = Vector2(270.0, 600.0)
	toilet.scale = Vector2(0.625, 0.625)
	_backdrop_world.add_child(toilet)
	# Gameplay's SurfaceEffects supplies blank stain maps. The menu uses the
	# same art without that controller, so its shaders need an explicit clean map.
	var clean_image := Image.create(1, 1, false, Image.FORMAT_L8)
	clean_image.fill(Color.BLACK)
	var clean_map := ImageTexture.create_from_image(clean_image)
	for sprite_path in ["BackWall", "Floor"]:
		_set_clean_stain_map(room.get_node(sprite_path) as Sprite2D, clean_map)
	for sprite_path in ["Bowl", "Tank", "Seat"]:
		_set_clean_stain_map(toilet.get_node(sprite_path) as Sprite2D, clean_map)


func _set_clean_stain_map(sprite: Sprite2D, clean_map: ImageTexture) -> void:
	var material := sprite.material.duplicate() as ShaderMaterial
	material.set_shader_parameter("stain_map", clean_map)
	sprite.material = material


func _show_title() -> void:
	_route_pending = false
	_backdrop_world.visible = true
	_play_menu_music()
	var title := TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	title.backdrop_opacity = 0.68
	title.transition_completed.connect(_on_title_transition_completed)
	_title_screen = title
	_mount_screen(title)


func _on_title_transition_completed(source: int) -> void:
	if not _claim_route():
		return
	_last_input_source = source
	call_deferred("_start_level", _first_level_id(), source)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not is_instance_valid(_title_screen):
		if is_instance_valid(_main_menu) or not _claim_route():
			return
		get_viewport().set_input_as_handled()
		call_deferred("_show_main_menu")


func _show_main_menu() -> void:
	_clear_active_level()
	_backdrop_world.visible = true
	_play_menu_music()
	_title_screen = null
	var menu := MAIN_MENU_SCENE.instantiate() as Control
	menu.call("set_input_source", _last_input_source)
	menu.connect("play_requested", _on_play_requested)
	menu.connect("credits_requested", _on_menu_credits_requested)
	_main_menu = menu
	_mount_screen(menu)
	_route_pending = false


func _on_play_requested(source: int) -> void:
	if not _claim_route():
		return
	_last_input_source = source
	_start_level(_first_level_id(), source)


func _start_level(level_id: StringName, source: int) -> void:
	var definition := _definition_for_id(level_id)
	if definition == null:
		_show_main_menu()
		return
	_route_pending = true
	GameAudio.reset_music()
	_attempt_generation += 1
	_last_input_source = source
	_current_level_id = level_id
	_title_screen = null
	_main_menu = null
	_results_screen = null
	_backdrop_world.visible = false
	_menu_music.stop()
	var level_resource := definition.get("scene") as PackedScene
	if level_resource == null:
		push_error("Level definition has no scene: %s" % level_id)
		_show_main_menu()
		return
	var level := level_resource.instantiate()
	# Levels start themselves when run directly in the editor. Keep an app-owned
	# attempt inactive until its result signals are connected.
	if _has_property(level, &"skip_title_screen"):
		level.set("skip_title_screen", false)
	_active_level = level
	_mount_screen(level)
	# Level 1 owns the warning and raid sequence. Once that presentation ends,
	# the app moves a baked frame into a dedicated game-over scene.
	_connect_level_result(
		level,
		"failure_presentation_ready",
		Callable(self, "_on_failure_presentation_ready"),
		_attempt_generation,
	)
	_route_pending = false
	if level.has_method("begin_attempt"):
		level.call("begin_attempt", source)
	else:
		# Allows the shell to run while the level contract is being added.
		if _has_property(level, &"skip_title_screen"):
			level.set("skip_title_screen", true)
		if _has_property(level, &"initial_input_source"):
			level.set("initial_input_source", source)
		if level.has_method("start_gameplay_immediately"):
			level.call("start_gameplay_immediately")


func _on_failure_presentation_ready(generation: int) -> void:
	if generation != _attempt_generation or not _claim_route():
		return
	var frame: Image
	if DisplayServer.get_name() != "headless":
		var viewport_texture := get_viewport().get_texture()
		if viewport_texture:
			frame = viewport_texture.get_image()
	call_deferred("_show_failure_screen", frame, generation)


func _show_failure_screen(frame: Image, generation: int) -> void:
	if generation != _attempt_generation or not is_instance_valid(_active_level):
		_route_pending = false
		return
	var level := _active_level as Main
	var duration := level.failure_exit_duration
	var rotation_radians := level.failure_exit_rotation
	_last_input_source = level.input_controller.current_input_source
	_active_level = null
	var failure := FAILURE_SCREEN_SCENE.instantiate() as FailureScreen
	failure.retry_requested.connect(_on_failure_retry_requested)
	_mount_screen(failure)
	failure.show_failure(frame, duration, rotation_radians)
	_route_pending = false


func _on_failure_retry_requested() -> void:
	if not _claim_route():
		return
	_start_level(_current_level_id, _last_input_source)


func _connect_level_result(
		level: Node,
		signal_name: StringName,
		callback: Callable,
		generation: int,
) -> void:
	if not level.has_signal(signal_name):
		return
	var argument_count := 0
	for signal_info in level.get_signal_list():
		if StringName(signal_info.name) == signal_name:
			argument_count = signal_info.args.size()
			break
	var target := callback
	if argument_count > 0:
		target = target.unbind(argument_count)
	target = target.bind(generation)
	var result_signal := Signal(level, signal_name)
	if not result_signal.is_connected(target):
		result_signal.connect(target)


func _on_level_completed(generation: int) -> void:
	if generation != _attempt_generation or not _claim_route():
		return
	call_deferred("_show_results", true, generation)


func _on_level_failed(generation: int) -> void:
	if generation != _attempt_generation or not _claim_route():
		return
	call_deferred("_show_results", false, generation)


func _show_results(success: bool, generation: int) -> void:
	if generation != _attempt_generation or not is_instance_valid(_active_level):
		_route_pending = false
		return
	var definition := _definition_for_id(_current_level_id)
	if definition == null:
		_show_main_menu()
		return
	var next_level_id := _next_level_id(_current_level_id)
	_active_level = null
	_play_menu_music()
	var results := RESULTS_SCREEN_SCENE.instantiate() as Control
	results.call("configure", success, String(definition.get("display_name")), not next_level_id.is_empty())
	results.call("set_input_source", _last_input_source)
	results.connect("retry_requested", _on_retry_requested)
	results.connect("next_requested", _on_next_requested)
	results.connect("credits_requested", _on_results_credits_requested)
	results.connect("menu_requested", _on_results_menu_requested)
	_results_screen = results
	_mount_screen(results)
	_route_pending = false


func _on_retry_requested(source: int) -> void:
	if not _claim_route():
		return
	_start_level(_current_level_id, source)


func _on_next_requested(source: int) -> void:
	if not _claim_route():
		return
	var next_level_id := _next_level_id(_current_level_id)
	if not next_level_id.is_empty():
		_start_level(next_level_id, source)
	else:
		_open_credits(source)


func _on_results_credits_requested(source: int) -> void:
	if not _claim_route():
		return
	_open_credits(source)


func _on_results_menu_requested(source: int) -> void:
	if not _claim_route():
		return
	_last_input_source = source
	_show_main_menu()


func _on_menu_credits_requested(source: int) -> void:
	if not _claim_route():
		return
	_open_credits(source)


func _open_credits(source: int) -> void:
	_last_input_source = source
	_backdrop_world.visible = false
	_play_menu_music()
	if not ResourceLoader.exists(CREDITS_SCENE_PATH):
		push_warning("Credits scene is not available yet: %s" % CREDITS_SCENE_PATH)
		_show_main_menu()
		return
	var credits_resource := load(CREDITS_SCENE_PATH) as PackedScene
	if credits_resource == null:
		push_error("Could not load credits scene: %s" % CREDITS_SCENE_PATH)
		_show_main_menu()
		return
	var credits := credits_resource.instantiate()
	if credits.has_signal("back_requested"):
		credits.connect("back_requested", _on_credits_back_requested)
	_main_menu = null
	_results_screen = null
	_mount_screen(credits)
	_route_pending = false


func _on_credits_back_requested() -> void:
	if not _claim_route():
		return
	call_deferred("_show_main_menu")


func _mount_screen(screen: Node) -> void:
	if is_instance_valid(_active_screen):
		remove_child(_active_screen)
		_active_screen.queue_free()
	_active_screen = screen
	add_child(_active_screen)
	Input.set_mouse_mode(
		Input.MOUSE_MODE_HIDDEN if screen == _active_level else Input.MOUSE_MODE_VISIBLE,
	)


func _play_menu_music() -> void:
	if not _menu_music.playing:
		_menu_music.play()


func _clear_active_level() -> void:
	GameAudio.reset_music()
	if is_instance_valid(_active_level):
		_active_level = null
	_main_menu = null
	_results_screen = null
	_route_pending = false


func _claim_route() -> bool:
	if _route_pending:
		return false
	_route_pending = true
	return true


func _first_level_id() -> StringName:
	var first_definition := _definition_with_lowest_order()
	return StringName(first_definition.get("level_id")) if first_definition else &""


func _definition_for_id(level_id: StringName) -> Resource:
	for definition in level_definitions:
		if StringName(definition.get("level_id")) == level_id:
			return definition
	return null


func _definition_with_lowest_order() -> Resource:
	var selected: Resource
	for definition in level_definitions:
		if selected == null or int(definition.get("progression_order")) < int(selected.get("progression_order")):
			selected = definition
	return selected


func _next_level_id(level_id: StringName) -> StringName:
	var current_definition := _definition_for_id(level_id)
	if current_definition == null:
		return &""
	var current_order := int(current_definition.get("progression_order"))
	var selected: Resource
	for definition in level_definitions:
		var order := int(definition.get("progression_order"))
		if order <= current_order:
			continue
		if selected == null or order < int(selected.get("progression_order")):
			selected = definition
	return StringName(selected.get("level_id")) if selected else &""


func _has_property(object: Object, property_name: StringName) -> bool:
	for property_info in object.get_property_list():
		if StringName(property_info.name) == property_name:
			return true
	return false


func _source_for_start_event(event: InputEvent) -> int:
	if event is InputEventKey:
		var key := event as InputEventKey
		return SOURCE_KEYBOARD if key.pressed and not key.echo else -1
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		return SOURCE_MOUSE if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed and not mouse_button.canceled else -1
	if event is InputEventScreenTouch:
		return SOURCE_TOUCH if (event as InputEventScreenTouch).pressed else -1
	if event is InputEventJoypadButton:
		return SOURCE_CONTROLLER if (event as InputEventJoypadButton).pressed else -1
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) >= 0.2:
			return SOURCE_CONTROLLER
	return -1
