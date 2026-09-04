# Art source directory

Place opaque or alpha-silhouette PNG artwork here, then run
`godot --headless --script res://tools/bake_normal_maps.gd` from the project
root. The baker writes lossless `*_normal.png` maps and matching
`*_canvas_texture.tres` resources beside each source image.

The current stream blockout uses `stream_body_placeholder.png` as a seamless
vertical strip on a generated ribbon mesh. Its companion normal texture is a
technical placeholder for 2D lighting; replace both with the artist's diffuse
and normal pass while keeping the strip tileable along its long axis.

`stream_splash_placeholder.png` is a monochrome impact reference. It is kept
separate from the stream mesh so the impact treatment can become a decal or
particle sprite later.

`stream_particle_placeholder.png` is the current particle sprite: a white
circle with a black outline and transparent corners. It is shared by the
ambient droplets, sputter burst, and continuous floor/target impact effect.

`carrot_aim_placeholder.png` is the temporary black-border blockout for the
scene-authored aim indicator. It rotates around its base as the player drags
across the indicator's transparent horizontal input span; replace it with final carrot art
without changing the control scene or signal interface.
