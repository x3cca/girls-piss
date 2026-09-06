shader_type canvas_item;

// The controller paints this map with each committed stream chunk. It is
// persistent surface state, not the current crosshair position.
uniform sampler2D water_noise_map;
uniform vec2 water_noise_map_texel_size = vec2(0.004, 0.004);
uniform vec2 ripple_center = vec2(0.5, 0.5);
uniform float ripple_age = 0.0;
uniform float ripple_strength = 0.0;
uniform float ripple_frequency : hint_range(4.0, 80.0, 0.5) = 30.0;
uniform float ripple_speed : hint_range(0.0, 20.0, 0.1) = 5.0;
uniform float ripple_amplitude : hint_range(0.0, 0.05, 0.001) = 0.012;
uniform float ripple_decay : hint_range(0.0, 4.0, 0.05) = 0.7;
uniform float pop_duration : hint_range(0.05, 1.0, 0.01) = 0.45;
uniform float pop_radius : hint_range(0.01, 0.3, 0.01) = 0.14;
uniform float pop_ring_width : hint_range(0.002, 0.08, 0.002) = 0.012;
uniform float pop_distortion_strength : hint_range(0.0, 0.12, 0.001) = 0.05;
uniform float wave_frequency : hint_range(1.0, 40.0, 0.5) = 18.0;
uniform float wave_speed : hint_range(0.0, 6.0, 0.1) = 1.8;
uniform float wave_amplitude : hint_range(0.0, 0.04, 0.001) = 0.008;
uniform float noise_strength : hint_range(0.0, 0.04, 0.001) = 0.012;
// The water mask is clear at full meter and becomes more yellow as the meter
// approaches empty. This is a color/opacity blend, not a radial yellow decal.
uniform float water_yellowness : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 clear_water_color : source_color = vec4(0.18, 0.62, 1.0, 1.0);
uniform float clear_water_opacity : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform vec4 water_color : source_color = vec4(0.95, 0.83, 0.31, 1.0);
uniform float water_opacity : hint_range(0.0, 1.0, 0.01) = 0.48;


float water_noise_at(vec2 uv) {
	return texture(water_noise_map, clamp(uv, vec2(0.0), vec2(1.0))).r;
}


void fragment() {
	vec2 texel = max(water_noise_map_texel_size, vec2(0.0001));
	float local_noise = water_noise_at(UV);
	vec2 noise_gradient = vec2(
		water_noise_at(UV + vec2(texel.x, 0.0)) - water_noise_at(UV - vec2(texel.x, 0.0)),
		water_noise_at(UV + vec2(0.0, texel.y)) - water_noise_at(UV - vec2(0.0, texel.y))
	);

	// Animated waves cover the whole bowl. The persistent map changes their
	// phase and adds local distortion wherever more stream chunks have landed.
	float noise_phase = local_noise * 6.2831853;
	vec2 waves = vec2(
		sin(UV.y * wave_frequency + ripple_age * wave_speed + noise_phase),
		sin(UV.x * wave_frequency * 1.17 - ripple_age * wave_speed * 0.83 + noise_phase * 1.31)
	) * wave_amplitude;
	vec2 persistent_distortion = noise_gradient * noise_strength;

	// One decaying impact ripple, anchored to the latest real bowl contact.
	vec2 from_impact = UV - ripple_center;
	float distance_to_impact = length(from_impact);
	vec2 impact_direction = from_impact / max(distance_to_impact, 0.0001);
	float ripple_wave = sin(
		distance_to_impact * ripple_frequency - ripple_age * ripple_speed
	);
	float ripple_mask = smoothstep(1.0, 0.0, distance_to_impact);
	ripple_mask *= smoothstep(0.0, 0.025, distance_to_impact);
	float ripple_fade = exp(-ripple_age * ripple_decay);
	vec2 impact_distortion = impact_direction * ripple_wave * ripple_amplitude;
	impact_distortion *= ripple_mask * ripple_fade * ripple_strength;

	// A short impact pop sells the stream landing with one sharp, strongly
	// displaced expanding ring before the slower ripple takes over.
	float pop_progress = clamp(ripple_age / pop_duration, 0.0, 1.0);
	float pop_fade = (1.0 - pop_progress) * ripple_strength;
	float pop_distance = pop_progress * pop_radius;
	float pop_ring = exp(-pow((distance_to_impact - pop_distance) / pop_ring_width, 2.0));
	float pop_trail = exp(
		-pow((distance_to_impact - pop_distance + pop_ring_width * 1.5) / pop_ring_width, 2.0)
	);
	float pop_profile = pop_ring - pop_trail * 0.35;
	vec2 pop_offset = impact_direction * pop_profile * pop_distortion_strength * pop_fade;

	vec2 distortion = waves + persistent_distortion + impact_distortion + pop_offset;
	vec4 base = texture(TEXTURE, clamp(UV + distortion, vec2(0.0), vec2(1.0)));
	base.a *= COLOR.a;
	float water_shade = mix(0.88, 1.08, local_noise);
	vec3 liquid_color = mix(clear_water_color.rgb, water_color.rgb, water_yellowness);
	float liquid_opacity = mix(
		clear_water_opacity * clear_water_color.a,
		water_opacity * water_color.a,
		water_yellowness
	);
	base.rgb = liquid_color * water_shade;
	base.a *= liquid_opacity;
	COLOR = base;
}
