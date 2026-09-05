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
ambient droplets and the continuous floor impact effect.

`carrot_aim_placeholder.png` is the temporary centered player marker. It is a
visual-only sprite now; the circular aimer owns all aiming input.

`aimer_placeholder.png` is a temporary transparent black-and-white circular
crosshair/trace-target sprite. It follows the current keyboard or touch target;
it is also used by trace targets. Replace it with authored 2D target art; these
sprites receive the shared boil shader at runtime.

Artwork pulled from the shared Google Drive lives under `drive/`. Use
`tools/sync_drive_assets.py --check` to inspect new source files and
`tools/sync_drive_assets.py --sync` to download them, trim transparent borders,
and convert them to lossless PNGs. The title uses the separate transparent
layers in `drive/` through `scenes/title_composition.tscn`; keep their authored
1080x1920 placements when composing them.

The contextual prompt still uses temporary labels under
`assets/placeholders/`: `aim.png` and `piss.png`. Keep those rows separate until
final descriptive assets replace them. The old title placeholders are retained
for development history but are not referenced by the title scene.
