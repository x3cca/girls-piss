shader_type canvas_item;

// Wall and tank use the same persistent stain map as the other surfaces. The
// brush shape is authored by SurfaceEffects, so this shader never follows the
// current cursor or endpoint after a spot has been stamped.
uniform sampler2D stain_map;
uniform vec4 stain_color : source_color = vec4(0.95, 0.83, 0.31, 1.0);
uniform float stain_opacity = 0.62;


void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float stain = texture(stain_map, UV).r;
	float yellow_amount = clamp(stain * stain_opacity * stain_color.a, 0.0, 1.0);
	vec3 shaded = mix(base.rgb, stain_color.rgb, yellow_amount);
	COLOR = vec4(shaded, base.a);
}
