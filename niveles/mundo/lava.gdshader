shader_type spatial;
render_mode cull_disabled;

uniform vec3 color_costra : source_color = vec3(0.06, 0.02, 0.02);
uniform vec3 color_lava : source_color = vec3(1.0, 0.35, 0.02);
uniform float escala = 80.0;
uniform float velocidad = 0.04;
uniform float escala_textura = 25.0;

uniform sampler2D textura_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D textura_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D textura_emision : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D textura_rugosidad : hint_roughness_gray, filter_linear_mipmap_anisotropic, repeat_enable;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i).x;
	float b = hash2(i + vec2(1.0, 0.0)).x;
	float c = hash2(i + vec2(0.0, 1.0)).x;
	float d = hash2(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Varias octavas con rotación entre cada una: así no se alinean con la cuadrícula del UV.
float fbm(vec2 p) {
	float suma = 0.0;
	float amplitud = 0.5;
	mat2 rotacion = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		suma += amplitud * ruido(p);
		p = rotacion * p * 2.02;
		amplitud *= 0.5;
	}
	return suma;
}

// Distancia a los bordes de las celdas de Voronoi: cerca de 0 forman las grietas.
float grietas(vec2 p) {
	vec2 celda = floor(p);
	vec2 local = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 vecino = vec2(float(x), float(y));
			vec2 punto = hash2(celda + vecino);
			vec2 r = vecino + punto - local;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

void fragment() {
	vec2 p = UV * escala;
	vec2 flujo = vec2(TIME * velocidad, -TIME * velocidad * 0.7);
	// Deformar las celdas con ruido hace que las grietas sean orgánicas.
	vec2 deformacion = vec2(fbm(p * 0.6 + flujo), fbm(p * 0.6 - flujo + 7.3)) * 1.6;
	float grieta = 1.0 - smoothstep(0.0, 0.15, grietas(p + deformacion));
	float calor = fbm(p * 0.5 - flujo * 2.0);
	float pulso = 0.9 + 0.15 * sin(TIME * 0.8 + calor * 6.0);
	
	// Muestreo de textura PBR con dos capas fluidas superpuestas
	vec2 uv_pbr1 = UV * escala_textura + flujo * 0.4;
	vec2 uv_pbr2 = UV * escala_textura * 1.25 - flujo * 0.3;
	vec4 col1 = texture(textura_albedo, uv_pbr1);
	vec4 col2 = texture(textura_albedo, uv_pbr2);
	vec3 tex_albedo = mix(col1.rgb, col2.rgb, 0.5);
	
	vec3 norm1 = texture(textura_normal, uv_pbr1).rgb * 2.0 - 1.0;
	vec3 norm2 = texture(textura_normal, uv_pbr2).rgb * 2.0 - 1.0;
	vec3 tex_normal = normalize(norm1 + norm2);
	
	vec3 em1 = texture(textura_emision, uv_pbr1).rgb;
	vec3 em2 = texture(textura_emision, uv_pbr2).rgb;
	vec3 tex_emision = max(em1, em2);
	
	float rug1 = texture(textura_rugosidad, uv_pbr1).r;
	float rug2 = texture(textura_rugosidad, uv_pbr2).r;
	float tex_rough = mix(rug1, rug2, 0.5);

	vec3 costra = mix(color_costra, tex_albedo * 0.6, 0.7) * (0.6 + 0.5 * calor);
	vec3 lava_nucleo = mix(color_lava, vec3(1.0, 0.8, 0.2), calor * 0.5);
	
	ALBEDO = mix(costra, lava_nucleo, grieta);
	NORMAL_MAP = tex_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2;
	
	vec3 emision_total = (lava_nucleo * grieta * pulso * 2.2) + (tex_emision * (1.0 - grieta * 0.5) * 1.5);
	EMISSION = emision_total;
	ROUGHNESS = mix(tex_rough, 0.25, grieta);
}
