shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(1.0, 0.2, 0.25, 0.72);
uniform float inner_radius = 0.28;
uniform float outer_radius = 0.76;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float distance_from_center = length(centered);
	float edge = smoothstep(inner_radius, outer_radius, distance_from_center);
	COLOR = vec4(vignette_color.rgb, vignette_color.a * edge);
}
