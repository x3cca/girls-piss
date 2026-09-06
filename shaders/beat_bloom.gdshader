shader_type canvas_item;
render_mode blend_add;

uniform vec4 bloom_color : source_color = vec4(1.0, 0.92, 0.42, 1.0);
uniform float bloom_strength = 1.0;

varying vec4 vertex_modulate;


void vertex() {
	vertex_modulate = COLOR;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// The wider bloom ribbon is brightest at its center and feathers out before
	// its edge. The source texture keeps the stream's existing hand-painted
	// breakup while the additive blend supplies the beat-hit glow.
	float side_falloff = smoothstep(0.0, 0.18, UV.x) * smoothstep(0.82, 1.0, 1.0 - UV.x);
	float alpha = source.a * vertex_modulate.a * side_falloff * bloom_strength;
	COLOR = vec4(bloom_color.rgb * alpha, alpha);
}
