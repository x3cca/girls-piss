extends GutTest


func test_new_aim_only_changes_newly_emitted_parcel() -> void:
	var stream_scene := load("res://scenes/liquid_stream.tscn") as PackedScene
	var stream := stream_scene.instantiate() as LiquidStream
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
