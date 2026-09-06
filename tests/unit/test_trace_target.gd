extends GutTest

const ITEM_MATERIAL := preload("res://resources/materials/item_outline.tres")


func test_target_uses_the_black_item_outline_material() -> void:
	var target := TraceTarget.new()
	add_child_autofree(target)

	var sprite := target.get_node("Sprite") as Sprite2D
	assert_eq(sprite.material, ITEM_MATERIAL)
	var material := sprite.material as ShaderMaterial
	assert_not_null(material)
	if material == null:
		return
	assert_eq(material.get_shader_parameter("outline_color"), Color(0, 0, 0, 1))
	assert_almost_eq(material.get_shader_parameter("outline_width"), 6.0, 0.001)


func test_target_has_subtle_idle_float_motion() -> void:
	var target := TraceTarget.new()
	add_child_autofree(target)
	target.configure(Vector2(120.0, 180.0), Vector2(360.0, 640.0), null, 48.0, 0.0)
	target.set_process(false)

	var start_position := target.position
	target.process_frame(0.5)

	assert_true(absf(target.position.y - start_position.y) < target.bob_amplitude)
	assert_true(not is_equal_approx(target.rotation, 0.0))
	assert_true(not is_equal_approx(target.scale.x, 1.0))


func test_target_swirl_finishes_at_the_center_and_hides() -> void:
	var target := TraceTarget.new()
	add_child_autofree(target)
	var center := Vector2(360.0, 640.0)
	target.configure(Vector2(120.0, 180.0), center, null, 48.0, 0.0)
	target.set_process(false)
	target.trigger_hit(center)
	target.process_frame(target.hit_duration)

	assert_true(target.is_hit())
	assert_true(target.position.distance_to(center) < 0.001)
	assert_false(target.visible)
	assert_true(target.scale.length() < 0.001)


func test_target_hitbox_matches_texture_alpha_in_world_space() -> void:
	var target := TraceTarget.new()
	add_child_autofree(target)
	var image := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in range(18, 22):
		for y in range(40):
			image.set_pixel(x, y, Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var center := Vector2(360.0, 640.0)
	target.configure(center, center, texture, 48.0, 0.0)
	target.set_process(false)

	assert_true(target.has_collision_mask())
	assert_true(target.contains_point(center))
	# The generous buffer reaches transparent pixels near the visible stroke.
	assert_true(target.contains_point(center + Vector2(12.0, 0.0)))
	# Transparent padding farther away than the generous buffer must not count.
	assert_false(target.contains_point(center + Vector2(50.0, 0.0)))

	target.rotation = PI * 0.5
	assert_true(target.contains_point(center))
	assert_true(target.contains_point(center + Vector2(0.0, 12.0)))
	assert_false(target.contains_point(center + Vector2(0.0, 50.0)))


func test_target_health_drains_and_contact_spin_accelerates() -> void:
	var target := TraceTarget.new()
	add_child_autofree(target)
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	target.configure(
		Vector2(360.0, 640.0),
		Vector2(360.0, 640.0),
		ImageTexture.create_from_image(image),
		48.0,
		0.0,
	)
	target.set_process(false)
	target.max_health = 3.0
	target.contact_damage_per_second = 3.0
	target.reset_target()

	assert_almost_eq(target.get_health_ratio(), 1.0, 0.001)
	target.apply_contact(0.1)
	var first_spin_speed := target._contact_spin_velocity
	target.apply_contact(0.1)
	var second_spin_speed := target._contact_spin_velocity

	assert_lt(target.health, target.max_health)
	assert_gt(second_spin_speed, first_spin_speed)
	assert_gt(target._contact_spin_angle, 0.0)
	assert_almost_eq(target.get_health_ratio(), 0.8, 0.001)
