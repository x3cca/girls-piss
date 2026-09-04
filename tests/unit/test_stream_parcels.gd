extends GutTest

const STREAM_SCENE := preload("res://scenes/liquid_stream.tscn")


func test_new_aim_only_changes_newly_emitted_parcel() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.gravity = Vector2.ZERO
	stream.source_position = Vector2.ZERO
	stream.emit_parcels(Vector2.UP, 0.8, 0.0)
	stream.update_parcels(0.1)
	var old_position: Vector2 = stream._parcels[0]["position"]
	var old_launch_velocity: Vector2 = stream._parcels[0]["launch_velocity"]

	stream.emit_parcels(Vector2.RIGHT, 0.1, 0.0)
	var new_launch_velocity: Vector2 = stream._parcels[0]["launch_velocity"]
	var old_parcel: Dictionary = stream._parcels[1]

	assert_eq(new_launch_velocity, Vector2.RIGHT * 616.0)
	assert_eq(old_parcel["launch_velocity"], old_launch_velocity)
	assert_eq(old_parcel["position"], old_position)


func test_sputter_profile_reduces_continuity_and_increases_bursts() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	var normal := stream.get_sputter_profile(0.0, false)
	var low_pressure := stream.get_sputter_profile(0.65, false)
	var exhausted := stream.get_sputter_profile(1.0, true)

	assert_true(float(normal["emission_rate"]) > float(low_pressure["emission_rate"]))
	assert_true(float(low_pressure["burst_amount"]) > float(normal["burst_amount"]))
	assert_true(float(exhausted["burst_amount"]) > float(low_pressure["burst_amount"]))
	assert_eq(float(exhausted["emission_rate"]), 0.0)
	assert_eq(float(exhausted["ribbon_alpha"]), 0.0)
