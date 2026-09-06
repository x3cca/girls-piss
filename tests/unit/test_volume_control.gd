extends GutTest

const LEVEL_SCENE := preload("res://scenes/level_1.tscn")


func test_volume_control_cycles_three_even_levels_and_mute() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	var chrome := level.get_node("Level1Chrome") as Level1Chrome
	var master_bus := AudioServer.get_bus_index(&"Master")
	var original_volume_db := AudioServer.get_bus_volume_db(master_bus)
	var original_muted := AudioServer.is_bus_mute(master_bus)

	chrome.set_volume_level(1)
	assert_eq(chrome.get_volume_level(), 1)
	assert_false(chrome.is_muted())
	assert_eq(chrome.get_node("Volume").texture.resource_path, "res://assets/art/drive/Volume1.png")
	assert_almost_eq(AudioServer.get_bus_volume_db(master_bus), linear_to_db(1.0 / 3.0), 0.001)

	chrome.cycle_volume()
	assert_eq(chrome.get_volume_level(), 2)
	assert_eq(chrome.get_node("Volume").texture.resource_path, "res://assets/art/drive/Volume2.png")
	assert_almost_eq(AudioServer.get_bus_volume_db(master_bus), linear_to_db(2.0 / 3.0), 0.001)

	chrome.cycle_volume()
	assert_eq(chrome.get_volume_level(), 3)
	assert_eq(chrome.get_node("Volume").texture.resource_path, "res://assets/art/drive/Volume3.png")
	assert_almost_eq(AudioServer.get_bus_volume_db(master_bus), 0.0, 0.001)

	chrome.cycle_volume()
	assert_eq(chrome.get_volume_level(), 0)
	assert_true(chrome.is_muted())
	assert_true(AudioServer.is_bus_mute(master_bus))
	assert_eq(
		chrome.get_node("Volume").texture.resource_path,
		"res://assets/art/drive/MuteVolumeX.svg",
	)

	chrome.cycle_volume()
	assert_eq(chrome.get_volume_level(), 1)
	assert_false(chrome.is_muted())
	assert_false(AudioServer.is_bus_mute(master_bus))
	assert_not_null(chrome._wobble_tween)

	AudioServer.set_bus_volume_db(master_bus, original_volume_db)
	AudioServer.set_bus_mute(master_bus, original_muted)
