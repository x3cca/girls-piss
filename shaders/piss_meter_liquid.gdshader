shader_type canvas_item;

// The bar is drawn as a full-height texture and this mask controls how much
// of the colored liquid remains visible. UV.y is zero at the top of the bar.
uniform float fluid_amount : hint_range(0.0, 1.0) = 1.0;
uniform float wave_amplitude : hint_range(0.0, 0.05) = 0.012;
uniform float wave_frequency : hint_range(1.0, 24.0) = 9.0;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.8;
uniform float wave_softness : hint_range(0.001, 0.05) = 0.008;


void fragment() {
	float amount = clamp(fluid_amount, 0.0, 1.0);
	if (amount <= 0.0) {
		discard;
	}

	vec4 liquid = texture(TEXTURE, UV);
	float surface_y = 1.0 - amount;
	float wave_fade = smoothstep(0.0, 0.16, amount) * smoothstep(0.0, 0.16, 1.0 - amount);
	float wave = (
		sin(UV.x * wave_frequency + TIME * wave_speed) * wave_amplitude
		+ sin(UV.x * wave_frequency * 2.1 - TIME * wave_speed * 1.35)
		* wave_amplitude
		* 0.3
	) * wave_fade;
	float surface = surface_y + wave;
	float liquid_mask = smoothstep(
		surface - wave_softness,
		surface + wave_softness,
		UV.y
	);

	liquid.a *= liquid_mask;
	COLOR = liquid;
}
