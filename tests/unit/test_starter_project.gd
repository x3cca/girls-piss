extends GutTest

func test_smoke_scene_loads_and_has_starter_label() -> void:
	var smoke_scene := load("res://scenes/smoke_test.tscn") as PackedScene
	assert_not_null(smoke_scene, "The starter smoke scene should be loadable.")

	var smoke_instance := smoke_scene.instantiate()
	add_child_autofree(smoke_instance)

	assert_true(smoke_instance is Control)
	assert_eq(smoke_instance.name, "SmokeTest")
	var label := smoke_instance.get_node_or_null("Center/Label") as Label
	assert_not_null(label, "The smoke scene should contain a starter label.")
	if label == null:
		return
	assert_eq(
		label.text,
		"Godot jam starter ready",
		"The smoke scene should display the starter-ready label.",
	)
