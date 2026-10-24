shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Terreno: mistura grama, terra, pedra e areia pelos pesos guardados na cor do vértice
// (r = terra, g = pedra, b = areia, resto = grama; a = variação de tom).
// Feito pra ser leve no celular: as manchas são calculadas por vértice e só lê a textura
// das camadas que aparecem naquele ponto (no gramado é uma leitura só).
#include "res://shaders/atlas.gdshaderinc"
uniform float detail = 0.0;   // não usado (mantido pra compatibilidade)

varying vec3 wpos;
varying vec3 wnrm;
varying vec2 spots;   // x = mancha seca, y = queimado

float hh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hh(i), hh(i + vec2(1, 0)), u.x), mix(hh(i + vec2(0, 1)), hh(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
	float patch = vn(wpos.xz * 0.018) * 0.65 + vn(wpos.xz * 0.06) * 0.35;
	spots = vec2(smoothstep(0.55, 0.75, patch), smoothstep(0.8, 0.9, vn(wpos.xz * 0.011 + vec2(7.3, 1.9))));
}

void fragment() {
	vec2 uv = wpos.xz * 0.24;
	vec3 pdx = dFdx(wpos);
	vec3 pdy = dFdy(wpos);
	vec2 udx = pdx.xz * 0.24;
	vec2 udy = pdy.xz * 0.24;
	vec4 w = COLOR;
	float gw = clamp(1.0 - w.r - w.g - w.b, 0.0, 1.0);
	vec3 col = vec3(0.0);
	if (gw > 0.01) {
		vec3 g = atlas_sample_g(uv, 0.0, udx, udy);
		// grama seca e cansada: puxa pro oliva/palha, com manchas queimadas aqui e ali
		float gl = dot(g, vec3(0.3, 0.59, 0.11));
		g = mix(g, vec3(gl) * vec3(1.08, 1.0, 0.72), 0.08);
		g = mix(g, g * vec3(0.92, 0.82, 0.62), spots.x * 0.45);
		g = mix(g, vec3(0.16, 0.14, 0.12), spots.y * 0.45);
		g *= vec3(0.78, 0.92, 0.84);   // verde frio (sem amarelar)
		col += g * gw;
	}
	if (w.r > 0.01) {
		col += atlas_sample_g(uv * 0.9, 1.0, udx * 0.9, udy * 0.9) * w.r;
	}
	if (w.g > 0.01) {
		// pedra: projeção do lado mais virado (não estica nos barrancos), uma leitura só
		vec3 an = abs(wnrm);
		bool top = an.y > 0.7;
		bool sx = an.x > an.z;
		vec2 ruv = top ? wpos.xz : (sx ? wpos.zy : wpos.xy);
		vec2 rdx = top ? pdx.xz : (sx ? pdx.zy : pdx.xy);
		vec2 rdy = top ? pdy.xz : (sx ? pdy.zy : pdy.xy);
		col += atlas_sample_g(ruv * 0.2, 2.0, rdx * 0.2, rdy * 0.2) * 0.72 * w.g;
	}
	if (w.b > 0.01) {
		col += atlas_sample_g(uv * 1.3, 3.0, udx * 1.3, udy * 1.3) * 0.9 * w.b;
	}
	// praia da ilha (só a cor: a areia não muda onde as coisas nascem)
	float e = max(abs(wpos.x), abs(wpos.z));
	float beach = smoothstep(361.0, 376.0, e);
	if (beach > 0.01) {
		vec3 sd = atlas_sample_g(uv * 1.3, 3.0, udx * 1.3, udy * 1.3) * 0.95;
		sd *= mix(1.0, 0.6, smoothstep(-15.0, -19.0, wpos.y));   // molhada perto da água
		col = mix(col, sd, beach);
	}
	col *= mix(0.72, 1.12, w.a);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
