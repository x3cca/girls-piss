# Art source directory

Original project 2D artwork in this directory is covered by
[`LICENSES/RAQUEL_STONE_CUSTOM_ASSETS.md`](../../LICENSES/RAQUEL_STONE_CUSTOM_ASSETS.md).
Artwork with a separate attribution or license notice remains subject to that
notice.

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

The stream particles use the lemon squirt artwork from `drive/`: the
`PissOMeterLemonDrip1.png` sprite is used for ambient droplets and the primary
impact, while `PissOMeterLemonDrop2.png` is used for the secondary impact.

`carrot_aim_placeholder.png` is the temporary centered player marker. It is a
visual-only sprite now; the circular aimer owns all aiming input.

`aimer_placeholder.png` is a temporary transparent black-and-white circular
crosshair/trace-target sprite. It follows the current keyboard or touch target;
it is also used by trace targets. Replace it with authored 2D target art; these
sprites receive the shared boil shader at runtime.

Artwork pulled from the shared Google Drive lives under `drive/`. Use
`tools/sync_drive_assets.py --check` to inspect new source files and
`tools/sync_drive_assets.py --sync` to download them, trim transparent borders,
and convert them to lossless PNGs. Set `DRIVE_ASSETS_URL` or pass `--source`
with the folder URL at runtime. The title uses the separate transparent
layers in `drive/` through `scenes/title_composition.tscn`; keep their authored
1080x1920 placements when composing them.

`drive/GirlpissWaterin bowl.png` is the centered alpha mask for the bowl water
overlay. It is intentionally rendered above `Pissbowl.png` with the ripple
shader, while the bowl artwork remains the static silhouette underneath.

The contextual prompt still uses temporary labels under
`assets/placeholders/`: `aim.png` and `piss.png`. Keep those rows separate until
final descriptive assets replace them. The old title placeholders are retained
for development history but are not referenced by the title scene.
