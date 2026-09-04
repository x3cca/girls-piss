# Art source directory

Place opaque or alpha-silhouette PNG artwork here, then run
`godot --headless --script res://tools/bake_normal_maps.gd` from the project
root. The baker writes lossless `*_normal.png` maps and matching
`*_canvas_texture.tres` resources beside each source image.
