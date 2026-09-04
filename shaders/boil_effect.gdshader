// Adapted from the squigglevision shader used by dating-chess.
// Original reference: https://godotshaders.com/shader/squigglevision/
shader_type canvas_item;
render_mode world_vertex_coords;

group_uniforms Boil;
/**
 * Noise texture scale.
 * The noise texture's size in world coordinates is set by its resolution.
 */
uniform vec2 scale = vec2(1.0);
uniform float strength = 1.0;
/**
 * Number of boil frames per second.
 */
uniform float fps = 6.0;
uniform sampler2D noise : filter_linear, repeat_enable;
group_uniforms;

varying vec4 modulate;
varying vec2 noise_uv;


void vertex() {
	modulate = COLOR;

	// Keep the noise pattern attached to each object while making its scale
	// independent of the object's local transform.
	noise_uv = (VERTEX - MODEL_MATRIX[3].xy) / (vec2(textureSize(noise, 0)) * scale);
}


// Irrational offsets give each boil frame a different noise slice.
#define offset_multiplier vec2(PI, E)


void fragment() {
	vec2 noise_offset = vec2(floor(TIME * fps)) * offset_multiplier;
	float noise_sample = texture(noise, noise_uv + noise_offset).r * 4.0 * PI;
	vec2 direction = vec2(cos(noise_sample), sin(noise_sample));
	vec2 boiled_uv = UV + direction * strength * 0.005;

	COLOR = texture(TEXTURE, boiled_uv) * modulate;
}
