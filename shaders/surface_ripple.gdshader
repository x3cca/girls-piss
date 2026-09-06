shader_type canvas_item;

// Bowl marks are persistent too. The stain map's local gradient bends the
// bowl texture around every stamped spot, allowing many marks without a
// cursor-sized radial highlight or a list of transient waves.
uniform sampler2D stain_map;
uniform vec2 stain_map_texel_size = vec2(0.004, 0.004);
uniform float splat_threshold = 0.5;
uniform float splat_edge = 0.04;
uniform vec4 stain_color : source_color = vec4(0.95, 0.83, 0.31, 1.0);
uniform float stain_opacity = 0.62;
uniform float distortion_strength = 0.018;


float stain_at(vec2 uv) {
	return texture(stain_map, clamp(uv, vec2(0.0), vec2(1.0))).r;
}


void fragment() {
	// Keep the authored RGB untouched. Multiplying by the built-in COLOR shifts
	// these sRGB assets in the compatibility renderer even with a blank stain map.
	vec2 texel = max(stain_map_texel_size, vec2(0.0001));
	vec2 stain_gradient = vec2(
		stain_at(UV + vec2(texel.x, 0.0)) - stain_at(UV - vec2(texel.x, 0.0)),
		stain_at(UV + vec2(0.0, texel.y)) - stain_at(UV - vec2(0.0, texel.y))
	);
	vec2 distortion = stain_gradient * distortion_strength;
	vec4 base = texture(TEXTURE, clamp(UV + distortion, vec2(0.0), vec2(1.0)));
	base.a *= COLOR.a;
	float stain = stain_at(UV);
	float binary_splat = smoothstep(
		splat_threshold - splat_edge,
		splat_threshold + splat_edge,
		stain
	);
	float yellow_amount = binary_splat * stain_opacity * stain_color.a;
	vec3 shaded = mix(base.rgb, stain_color.rgb, yellow_amount);
	COLOR = vec4(shaded, base.a);
}
