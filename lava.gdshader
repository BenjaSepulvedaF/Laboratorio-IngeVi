shader_type spatial;
render_mode cull_disabled;

uniform vec3 color_costra : source_color = vec3(0.055, 0.018, 0.02);
uniform vec3 color_lava : source_color = vec3(1.0, 0.22, 0.015);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 150.0;
	vec2 flujo = vec2(TIME * 0.035, TIME * -0.025);
	float n = ruido(p + flujo) * 0.65 + ruido(p * 2.1 - flujo) * 0.25 + ruido(p * 4.0) * 0.1;
	float grieta = 1.0 - smoothstep(0.015, 0.075, abs(n - 0.5));
	float pulso = 0.85 + 0.15 * sin(TIME * 0.8 + n * 9.0);
	ALBEDO = mix(color_costra, color_lava, grieta * 0.85);
	EMISSION = color_lava * grieta * pulso * 1.8;
	ROUGHNESS = 0.85;
}
