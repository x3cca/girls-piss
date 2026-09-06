shader_type canvas_item;

// The controller owns a small, level-local texture containing accumulated pee
// spots. It is sampled in the surface's own UV space, so old spots stay where
// they were painted instead of following the latest endpoint.
uniform sampler2D stain_map;
uniform float splat_threshold = 0.5;
uniform float splat_edge = 0.04;
uniform vec4 stain_color : source_color = vec4(0.95, 0.83, 0.31, 1.0);
uniform float stain_opacity = 0.62;
// The bowl keeps its splat shader, but its water mask suppresses splats below
// the separate animated water layer.
uniform sampler2D water_mask;
uniform vec4 water_mask_uv_transform = vec4(1.0, 1.0, 0.0, 0.0);
uniform float water_mask_enabled = 0.0;


void fragment() {
	// Keep the authored RGB untouched. Multiplying by the built-in COLOR shifts
	// these sRGB assets in the compatibility renderer even with a blank stain map.
	vec4 base = texture(TEXTURE, UV);
	base.a *= COLOR.a;
	float stain = texture(stain_map, UV).r;
	float binary_splat = smoothstep(
		splat_threshold - splat_edge,
		splat_threshold + splat_edge,
		stain
	);
	float water_coverage = 0.0;
	if (water_mask_enabled > 0.5) {
		vec2 water_uv = UV * water_mask_uv_transform.xy + water_mask_uv_transform.zw;
		if (
				water_uv.x >= 0.0
				&& water_uv.x <= 1.0
				&& water_uv.y >= 0.0
				&& water_uv.y <= 1.0
		) {
			water_coverage = texture(water_mask, water_uv).a;
		}
	}
	binary_splat *= 1.0 - water_coverage;
	float yellow_amount = binary_splat * stain_opacity * stain_color.a;
	vec3 shaded = mix(base.rgb, stain_color.rgb, yellow_amount);
	COLOR = vec4(shaded, base.a);
}
