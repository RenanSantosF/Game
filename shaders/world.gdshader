shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Material de quase tudo: textura do atlas (camada em UV2.x) vezes a cor do vértice.
// UV2.y > 0 = balança com o vento (folhas).
// Paredes (reboco, tijolo, concreto) ganham sujeira escorrida e manchas de encardido.
#include "res://shaders/atlas.gdshaderinc"

varying float layer;
varying vec3 wpos;
varying float wall;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	layer = UV2.x;
	COLOR.rgb = pow(COLOR.rgb, vec3(2.2));
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float l = floor(UV2.x + 0.5);
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wall = (l == 4.0 || l == 5.0 || l == 9.0) ? (1.0 - abs(wn.y)) : 0.0;
	if (UV2.y > 0.0) {
		vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float s = sin(TIME * 1.3 + w.x * 0.11 + w.z * 0.07) * UV2.y * max(VERTEX.y - 2.0, 0.0) * 0.012;
		VERTEX.x += s;
		VERTEX.z += s * 0.6;
	}
}

void fragment() {
	vec3 t = atlas_sample(UV, layer);
	vec3 c = t * COLOR.rgb;
	if (wall > 0.5) {
		float h = mod(wpos.x + wpos.z, 256.0);
		// escorrido: faixas verticais finas que descem das janelas/telhado
		float streak = vnoise(vec2(h * 3.1, mod(wpos.y, 256.0) * 0.22)) * (0.6 + 0.4 * vnoise(vec2(h * 9.0, 0.5)));
		// manchas grandes de encardido / fumaça
		float blot = vnoise(vec2(h * 0.4, wpos.y * 0.5) + 11.0);
		float g = smoothstep(0.35, 0.8, streak) * 0.55 + smoothstep(0.45, 0.85, blot) * 0.45;
		c = mix(c, c * vec3(0.38, 0.33, 0.27), clamp(g, 0.0, 0.8) * wall);
	}
	ALBEDO = c;
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}
