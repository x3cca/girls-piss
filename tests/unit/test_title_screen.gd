extends GutTest

const TITLE_SCENE := preload("res://scenes/title_screen.tscn")
const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")


func test_title_starts_active_and_uses_shared_material_for_both_images() -> void:
	var title := TITLE_SCENE.instantiate() as TitleScreen
	title.entry_duration = 0.01
	title.start_delay = 0.25
	add_child_autofree(title)
	var logo := title.get_node("Overlay/Logo") as TextureRect
	var start := title.get_node("Overlay/Start") as TextureRect
	var viewport_size := get_viewport().get_visible_rect().size

	assert_true(title.is_active())
	assert_true(logo.material == BOIL_MATERIAL)
	assert_true(start.material == BOIL_MATERIAL)
	assert_eq(
		logo.texture.resource_path,
		"res://assets/art/drive/GirlsPiss-GirlsPiss-80085.png",
	)
	assert_eq(
		start.texture.resource_path,
		"res://assets/art/drive/GirlsPiss-GirlsPiss-80085-PressStart.png",
	)
	assert_eq(logo.texture.get_size(), Vector2(1698.0, 904.0))
	assert_eq(start.texture.get_size(), Vector2(1789.0, 505.0))
	assert_almost_eq(logo.position.y + logo.size.y * 0.5, viewport_size.y / 3.0, 0.001)

	await get_tree().create_timer(0.15).timeout
	assert_gt(start.position.y, title._start_final_position.y)
	await get_tree().create_timer(0.2).timeout
	assert_almost_eq(start.position.y, title._start_final_position.y, 0.02)


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
