shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Terreno: mistura grama, terra, pedra e areia pelos pesos guardados na cor do vértice
// (r = terra, g = pedra, b = areia, resto = grama; a = variação de tom).
#include "res://shaders/atlas.gdshaderinc"
uniform float detail = 1.0;

varying vec3 wpos;

float hh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hh(i), hh(i + vec2(1, 0)), u.x), mix(hh(i + vec2(0, 1)), hh(i + vec2(1, 1)), u.x), u.y);
}
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
}

void fragment() {
	vec2 uv = wpos.xz * 0.24;
	vec4 w = COLOR;
	vec3 g = atlas_sample(uv, 0.0);
	// segunda amostra em outra escala: esconde a repetição da grama
	vec3 g2 = atlas_sample(uv * 0.21 + vec2(0.37, 0.71), 0.0);
	g = mix(g, g2, 0.45 * detail);
	// grama seca e cansada: puxa pro oliva/palha, com manchas queimadas aqui e ali
	float gl = dot(g, vec3(0.3, 0.59, 0.11));
	g = mix(g, vec3(gl) * vec3(1.08, 1.0, 0.72), 0.08);
	float patch = vn(wpos.xz * 0.018) * 0.65 + vn(wpos.xz * 0.06) * 0.35;
	g = mix(g, g * vec3(0.92, 0.82, 0.62), smoothstep(0.55, 0.75, patch) * 0.45);
	float burnt = smoothstep(0.8, 0.9, vn(wpos.xz * 0.011 + vec2(7.3, 1.9)));
	g = mix(g, vec3(0.16, 0.14, 0.12), burnt * 0.45);
	g *= vec3(0.78, 0.92, 0.84);   // verde frio (sem amarelar)
	vec3 d = atlas_sample(uv * 0.9, 1.0);
	// pedra em três projeções (não estica nos barrancos)
	vec3 bw = pow(abs(wnrm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 r = atlas_sample(wpos.zy * 0.2, 2.0) * bw.x
		+ atlas_sample(wpos.xz * 0.2, 2.0) * bw.y
		+ atlas_sample(wpos.xy * 0.2, 2.0) * bw.z;
	vec3 s = atlas_sample(uv * 1.3, 3.0);
	float gw = clamp(1.0 - w.r - w.g - w.b, 0.0, 1.0);
	vec3 col = g * gw + d * w.r + r * 0.72 * w.g + s * 0.9 * w.b;
	col *= mix(0.72, 1.12, w.a);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
