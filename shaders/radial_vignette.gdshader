shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(1.0, 0.2, 0.25, 0.72);
uniform float inner_radius = 0.28;
uniform float outer_radius = 0.76;
// Passed by the effect instead of deriving it from SCREEN_PIXEL_SIZE. The
// latter can be unavailable while a WebGL canvas is being resized, which
// makes the aspect correction infinite and fills the whole overlay.
uniform float aspect_ratio = 1.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	centered.x *= aspect_ratio;
	float distance_from_center = length(centered);
	float edge = smoothstep(inner_radius, outer_radius, distance_from_center);
	COLOR = vec4(vignette_color.rgb, vignette_color.a * edge);
}
