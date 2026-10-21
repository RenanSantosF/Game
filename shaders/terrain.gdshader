shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Terreno: mistura grama, terra, pedra e areia pelos pesos guardados na cor do vértice
// (r = terra, g = pedra, b = areia, resto = grama; a = variação de tom).
uniform sampler2DArray tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
}

void fragment() {
	vec2 uv = wpos.xz * 0.24;
	vec4 w = COLOR;
	vec3 g = texture(tex, vec3(uv, 0.0)).rgb;
	// segunda amostra em outra escala: esconde a repetição da grama
	vec3 g2 = texture(tex, vec3(uv * 0.21 + vec2(0.37, 0.71), 0.0)).rgb;
	g = mix(g, g2, 0.45 * detail);
	vec3 d = texture(tex, vec3(uv * 0.9, 1.0)).rgb;
	// pedra em três projeções (não estica nos barrancos)
	vec3 bw = pow(abs(wnrm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 r = vec3(0.0);
	if (w.g > 0.01) {
		r = texture(tex, vec3(wpos.zy * 0.2, 2.0)).rgb * bw.x
			+ texture(tex, vec3(wpos.xz * 0.2, 2.0)).rgb * bw.y
			+ texture(tex, vec3(wpos.xy * 0.2, 2.0)).rgb * bw.z;
	}
	vec3 s = texture(tex, vec3(uv * 1.3, 3.0)).rgb;
	float gw = clamp(1.0 - w.r - w.g - w.b, 0.0, 1.0);
	vec3 col = g * gw + d * w.r + r * 0.72 * w.g + s * 0.9 * w.b;
	col *= mix(0.72, 1.12, w.a);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
