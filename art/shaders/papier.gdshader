shader_type canvas_item;
// Grain de papier et vignettage, posés par-dessus le monde (sous l'interface).
uniform float grain = 0.06;
uniform float vignette = 0.35;
uniform vec4 c_vignette : source_color = vec4(0.08, 0.05, 0.1, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float g = hash(floor(p * 0.5)) * 0.6 + hash(floor(p * 0.125)) * 0.4;
	float v = smoothstep(0.45, 1.05, length(UV - 0.5) * 1.6);
	float a = v * vignette + abs(g - 0.5) * grain;
	vec3 col = mix(vec3(g * 0.6 + 0.2), c_vignette.rgb, step(0.001, v * vignette) * v);
	COLOR = vec4(col, a);
}
