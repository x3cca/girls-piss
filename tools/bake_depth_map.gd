extends SceneTree
## Run with:
##   godot --headless --path . --script res://tools/bake_depth_map.gd
##
## The checked-in prototype uses the small SVG map for portability, while this
## command is the editor/offline path for producing a raster bake from the
## tagged environment scene.

const ENVIRONMENT_SCENE := "res://scenes/depth_environment.tscn"
const OUTPUT_PATH := "res://resources/depth_map_baked.png"
const WORLD_RECT := Rect2(0.0, 0.0, 720.0, 1280.0)
const OUTPUT_SIZE := Vector2i(720, 1280)


func _init() -> void:
	var environment: Node = load(ENVIRONMENT_SCENE).instantiate()
	root.add_child(environment)
	await process_frame
	var baker := DepthMapBaker.new()
	root.add_child(baker)
	var result := baker.bake_to_file(environment, WORLD_RECT, OUTPUT_SIZE, OUTPUT_PATH)
	print("Depth map bake: ", result, " -> ", OUTPUT_PATH)
	quit(result)
