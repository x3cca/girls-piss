// Target-item material: preserve the game's subtle boil motion while adding
// a crisp silhouette outside the transparent pixels of each item texture.
shader_type canvas_item;
render_mode world_vertex_coords;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width = 6.0;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform vec2 noise_scale = vec2(0.01, 0.01);
uniform float boil_strength = 0.1;
uniform float boil_fps = 6.0;

varying vec4 modulate;
varying vec2 noise_uv;


void vertex() {
	modulate = COLOR;

	// Grow the quad so the outline has room to render outside the source
	// texture. UV is allowed to extend beyond the texture and is guarded in
	// fragment() so transparent space stays transparent.
	vec2 outline_uv = TEXTURE_PIXEL_SIZE * outline_width;
	VERTEX += (UV * 2.0 - 1.0) * outline_width;
	UV = UV * (1.0 + outline_uv * 2.0) - outline_uv;

	// Keep the boil noise attached to the item in world space, as it is for
	// the other animated artwork in the game.
	noise_uv = (VERTEX - MODEL_MATRIX[3].xy) /
		(vec2(textureSize(noise, 0)) * noise_scale);
}


bool is_inside_texture(vec2 uv) {
	return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}


void fragment() {
	float source_alpha = 0.0;
	vec2 boiled_uv = UV;
	if (is_inside_texture(UV)) {
		float noise_sample = texture(noise, noise_uv + vec2(floor(TIME * boil_fps)) * vec2(PI, E)).r;
		float noise_angle = noise_sample * 4.0 * PI;
		vec2 direction = vec2(cos(noise_angle), sin(noise_angle));
		boiled_uv = clamp(UV + direction * boil_strength * 0.005, vec2(0.0), vec2(1.0));
		source_alpha = texture(TEXTURE, boiled_uv).a;
	}
	if (source_alpha > 0.001) {
		COLOR = texture(TEXTURE, boiled_uv) * modulate;
	} else {
		float outline_alpha = 0.0;
		for (int x = -4; x <= 4; x++) {
			for (int y = -4; y <= 4; y++) {
				vec2 offset = vec2(float(x), float(y));
				if (length(offset) <= outline_width) {
					vec2 sample_uv = UV + offset * TEXTURE_PIXEL_SIZE;
					if (is_inside_texture(sample_uv)) {
						outline_alpha = max(outline_alpha, texture(TEXTURE, sample_uv).a);
					}
				}
			}
		}

		COLOR = vec4(outline_color.rgb, outline_alpha * outline_color.a) * modulate;
	}
}
