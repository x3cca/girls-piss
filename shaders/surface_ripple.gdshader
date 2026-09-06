shader_type canvas_item;

// The controller paints this map with each committed stream chunk. It is
// persistent surface state, not the current crosshair position.
uniform sampler2D water_noise_map;
uniform vec2 water_noise_map_texel_size = vec2(0.004, 0.004);
uniform float ripple_age = 0.0;
uniform float wave_frequency : hint_range(1.0, 40.0, 0.5) = 18.0;
uniform float wave_speed : hint_range(0.0, 6.0, 0.1) = 1.8;
uniform float wave_amplitude : hint_range(0.0, 0.04, 0.001) = 0.008;
uniform float noise_strength : hint_range(0.0, 0.04, 0.001) = 0.012;
// The water mask is clear at full meter and becomes more yellow as the meter
// approaches empty. This is a color blend, not a radial yellow decal. Opacity
// stays fixed so the water never becomes clearer as it yellows.
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
	float wave_x = sin(
		UV.y * wave_frequency + ripple_age * wave_speed + noise_phase
	);
	float wave_y = sin(
		UV.x * wave_frequency * 1.17
		- ripple_age * wave_speed * 0.83
		+ noise_phase * 1.31
	);
	vec2 waves = vec2(wave_x, wave_y) * wave_amplitude;
	vec2 persistent_distortion = noise_gradient * noise_strength;

	// Keep the water motion broad and texture-driven. The pee impact does not
	// add a radial displacement; its visual feedback is handled by the tint.
	vec2 distortion = waves + persistent_distortion;
	vec4 base = texture(TEXTURE, clamp(UV + distortion, vec2(0.0), vec2(1.0)));
	base.a *= COLOR.a;
	// The source texture is a mostly-flat white mask, so UV distortion alone is
	// invisible across the middle of the bowl. Use the wave signal as lighting
	// as well, making the motion visible without exposing the stamped noise map.
	float wave_shade = 1.0 + (wave_x * 0.055) + (wave_y * 0.045);
	vec3 liquid_color = mix(clear_water_color.rgb, water_color.rgb, water_yellowness);
	float liquid_opacity = max(
		clear_water_opacity * clear_water_color.a,
		water_opacity * water_color.a
	);
	base.rgb = liquid_color * wave_shade;
	base.a *= liquid_opacity;
	COLOR = base;
}
