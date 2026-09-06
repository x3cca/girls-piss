extends GutTest

const TITLE_SCENE := preload("res://scenes/title_screen.tscn")
const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")


func test_title_uses_the_authored_transparent_layer_composition() -> void:
	var title := TITLE_SCENE.instantiate() as TitleScreen
	add_child_autofree(title)
	var composition := title.get_node("Overlay/TitleComposition") as TitleComposition

	assert_true(title.is_active())
	assert_eq(Input.get_mouse_mode(), Input.MOUSE_MODE_VISIBLE)
	assert_true(composition.visible)
	assert_true(composition.is_title_active())
	assert_eq(composition.get_frame(), 0)
	_assert_layer(composition, "TitleFlareLeft", "TitleFlareLeft.png", Vector2(6, 383), Vector2(463, 700))
	_assert_layer(composition, "TitleFlareRight", "TitleFlareRight.png", Vector2(711, 328), Vector2(334, 758))
	_assert_layer(composition, "TitleFlare3", "TitleFlare3.png", Vector2(354, 1042), Vector2(463, 152))
	_assert_layer(composition, "GirlsTitle", "GirlsTitle.png", Vector2(144, 219), Vector2(681, 482))
	_assert_layer(composition, "PissTitle", "PissTitle.png", Vector2(223, 489), Vector2(671, 605))
	_assert_layer(composition, "StartFrame1/StartBacker1", "StartBacker1.png", Vector2(243, 1197), Vector2(658, 315))
	_assert_layer(composition, "StartFrame1/Start1", "Start1.png", Vector2(339, 1223), Vector2(473, 273))
	_assert_layer(composition, "StartFrame2/StartBacker2", "StartBacker2.png", Vector2(229, 1187), Vector2(682, 325))
	_assert_layer(composition, "StartFrame2/Start2", "Start2.png", Vector2(333, 1225), Vector2(475, 262))

	assert_true(composition.get_node("GirlsTitle").material == BOIL_MATERIAL)
	assert_true(composition.get_node("PissTitle").material == BOIL_MATERIAL)
	assert_true(composition.get_node("StartFrame1/Start1").material == BOIL_MATERIAL)
	assert_true(composition.get_node("StartFrame2/Start2").material == BOIL_MATERIAL)
	assert_lt(composition.get_node("TitleFlare3").z_index, composition.get_node("GirlsTitle").z_index)
	assert_lt(composition.get_node("GirlsTitle").z_index, composition.get_node("PissTitle").z_index)
	assert_lt(composition.get_node("PissTitle").z_index, composition.get_node("StartFrame1").z_index)
	assert_true(composition.get_node("StartFrame1").visible)
	assert_false(composition.get_node("StartFrame2").visible)
	assert_eq(composition.modulate.a, 1.0)
	for layer_name in [
		"TitleFlareLeft",
		"TitleFlareRight",
		"TitleFlare3",
		"GirlsTitle",
		"PissTitle",
	]:
		var layer := composition.get_node(layer_name) as Sprite2D
		assert_eq(layer.offset, Vector2.ZERO)
		assert_eq(layer.rotation, 0.0)
	assert_almost_eq(composition.get_node("StartFrame1").position.y, 152.5, 0.001)
	assert_almost_eq(composition.get_node("StartFrame2").position.y, 157.5, 0.001)

	composition._process(composition.frame_duration)
	assert_eq(composition.get_frame(), 1)
	assert_false(composition.get_node("StartFrame1").visible)
	assert_true(composition.get_node("StartFrame2").visible)


func _assert_layer(
		composition: TitleComposition,
		path: String,
		filename: String,
		position: Vector2,
		size: Vector2,
) -> void:
	var layer := composition.get_node(path) as Sprite2D
	assert_not_null(layer)
	assert_eq(layer.texture.resource_path, "res://assets/art/drive/" + filename)
	assert_eq(layer.position, position)
	assert_eq(Vector2(layer.texture.get_size()), size)


func test_request_start_locks_duplicate_requests_until_exit_completes() -> void:
	var title := TITLE_SCENE.instantiate() as TitleScreen
	title.entry_duration = 0.01
	title.exit_duration = 0.05
	add_child_autofree(title)
	var completed: Array[int] = []
	title.transition_completed.connect(func(source: int): completed.append(source))

	assert_true(title.request_start(InputController.AimSource.MOUSE))
	assert_false(title.request_start(InputController.AimSource.KEYBOARD))
	assert_true(title.is_start_locked())
	await get_tree().create_timer(0.2).timeout

	assert_false(title.is_active())
	assert_false(title.is_start_locked())
	assert_eq(completed, [InputController.AimSource.MOUSE])


func test_request_start_plays_the_beer_sound() -> void:
	var title := TITLE_SCENE.instantiate() as TitleScreen
	title.autoplay = false
	add_child_autofree(title)
	title.show_title()

	var start_sound := title.get_node("StartSound") as AudioStreamPlayer
	assert_eq(
		start_sound.stream.resource_path,
		"res://assets/audio/beer_can_open_and_drink.ogg",
	)
	assert_false(start_sound.playing)

	assert_true(title.request_start(InputController.AimSource.KEYBOARD))
	assert_true(start_sound.playing)
	assert_false(title.request_start(InputController.AimSource.MOUSE))


func test_skip_to_gameplay_finishes_once_without_waiting_for_tween() -> void:
	var title := TITLE_SCENE.instantiate() as TitleScreen
	title.autoplay = false
	add_child_autofree(title)
	var completed: Array[int] = []
	title.transition_completed.connect(func(source: int): completed.append(source))

	title.show_title()
	assert_true(title.skip_to_gameplay())
	assert_false(title.is_active())
	assert_false(title.skip_to_gameplay())
	assert_eq(completed.size(), 1)
