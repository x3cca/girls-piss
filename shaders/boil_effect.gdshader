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
uniform sampler2D depth_clip_map : filter_nearest;
uniform vec4 depth_clip_rect = vec4(0.0, 0.0, 540.0, 960.0);
uniform float depth_clip_enabled = 0.0;
uniform float depth_clip_depth = 0.0;
uniform float depth_clip_epsilon = 0.02;
group_uniforms;

varying vec4 modulate;
varying vec2 noise_uv;
varying vec2 depth_world_position;


void vertex() {
	modulate = COLOR;

	// Keep the noise pattern attached to each object while making its scale
	// independent of the object's local transform.
	noise_uv = (VERTEX - MODEL_MATRIX[3].xy) / (vec2(textureSize(noise, 0)) * scale);
	depth_world_position = VERTEX;
}


// Irrational offsets give each boil frame a different noise slice.
#define offset_multiplier vec2(PI, E)


void fragment() {
	if (depth_clip_enabled > 0.5) {
		vec2 depth_uv = (depth_world_position - depth_clip_rect.xy) / depth_clip_rect.zw;
		if (
			depth_uv.x < 0.0
			|| depth_uv.x >= 1.0
			|| depth_uv.y < 0.0
			|| depth_uv.y >= 1.0
		) {
			discard;
		}
		vec4 depth_sample = texture(depth_clip_map, depth_uv);
		if (depth_sample.a <= 0.001 || depth_sample.r + depth_clip_epsilon < depth_clip_depth) {
			discard;
		}
	}
	vec2 noise_offset = vec2(floor(TIME * fps)) * offset_multiplier;
	float noise_sample = texture(noise, noise_uv + noise_offset).r * 4.0 * PI;
	vec2 direction = vec2(cos(noise_sample), sin(noise_sample));
	vec2 boiled_uv = UV + direction * strength * 0.005;

	COLOR = texture(TEXTURE, boiled_uv) * modulate;
}
