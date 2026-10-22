shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Boneco (sem textura própria): pinta por região usando a posição de descanso guardada nas UVs
// (UV = lado, altura; UV2.x = frente, em metros) e a região do osso (UV2.y: 0 pele/mão/cabeça,
// 1 tronco/braço, 2 perna, 3 pé). Tecido vem do atlas; cada jogador tem as suas cores.
#include "res://shaders/atlas.gdshaderinc"

uniform vec3 c_skin : source_color = vec3(0.78, 0.58, 0.45);
uniform vec3 c_shirt : source_color = vec3(0.3, 0.35, 0.25);
uniform vec3 c_pants : source_color = vec3(0.25, 0.27, 0.3);
uniform vec3 c_boots : source_color = vec3(0.12, 0.1, 0.08);
uniform vec3 c_hair : source_color = vec3(0.12, 0.09, 0.06);
uniform float camo = 0.0;       // 1 = camisa camuflada
uniform float sleeves = 1.0;    // 0 = manga curta
uniform float gloves = 0.0;     // 1 = luva tática

varying vec3 rp;
varying float bone_reg;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	rp = vec3(UV.x, UV.y, UV2.x);
	bone_reg = UV2.y;
}

void fragment() {
	float h = rp.y;
	float side = abs(rp.x);
	bool hand = bone_reg < 0.5 && h < 1.3;
	// tecido (trama do atlas) em duas escalas
	vec2 fu = vec2(rp.x + rp.z, h) * 7.0;
	vec3 fab = atlas_sample(fu, 14.0) * 1.15;
	vec3 shirt = c_shirt;
	if (camo > 0.5) {
		float n = vnoise(vec2(rp.x + rp.z * 0.7, h) * 9.0) + vnoise(vec2(rp.z - rp.x, h) * 17.0) * 0.5;
		shirt = n > 0.95 ? c_shirt * 0.55 : (n > 0.7 ? c_shirt * 1.25 : c_shirt);
	}
	shirt *= fab;
	vec3 pants = c_pants * fab;
	vec3 skin = c_skin;
	// cor por altura, com bordas suaves
	vec3 c = mix(pants, shirt, smoothstep(0.955, 0.975, h));
	// cinto
	float belt = smoothstep(0.93, 0.94, h) * (1.0 - smoothstep(0.975, 0.985, h));
	c = mix(c, vec3(0.09, 0.07, 0.05), belt * step(side, 0.2));
	// botas (com cano)
	c = mix(c, c_boots * (0.85 + 0.15 * fab.g), 1.0 - smoothstep(0.17, 0.19, h));
	// pescoço/cabeça
	c = mix(c, skin, smoothstep(1.43, 1.46, h));
	// manga curta: antebraço de pele
	if (sleeves < 0.5 && side > 0.25 && h > 1.0) c = mix(c, skin, smoothstep(0.3, 0.34, side));
	// mãos
	if (hand) c = gloves > 0.5 ? vec3(0.08, 0.08, 0.08) : skin;
	// cabelo: topo e nuca, deixando o rosto
	float face = smoothstep(0.035, 0.06, rp.z) * (1.0 - smoothstep(1.645, 1.665, h));
	float hair = smoothstep(1.575, 1.6, h) * (1.0 - face);
	hair = max(hair, smoothstep(1.53, 1.56, h) * (1.0 - smoothstep(-0.02, 0.01, rp.z)));
	c = mix(c, c_hair * (0.8 + 0.3 * vnoise(rp.xy * 120.0)), clamp(hair, 0.0, 1.0) * step(1.43, h));
	// rosto: sobrancelha e sombra dos olhos
	float eye = (1.0 - smoothstep(0.012, 0.02, abs(side - 0.033))) * (1.0 - smoothstep(0.006, 0.012, abs(h - 1.585))) * smoothstep(0.05, 0.07, rp.z);
	c = mix(c, c_hair * 0.8, eye * 0.8);
	// sombra entre as pernas
	c *= mix(0.8, 1.0, smoothstep(0.02, 0.09, side) + step(0.9, h));
	ALBEDO = c;
	bool is_skin = h > 1.45 && hair < 0.5 || hand;
	ROUGHNESS = is_skin ? 0.55 : 0.92;
	SPECULAR = is_skin ? 0.35 : 0.15;
	// borda iluminada: destaca o boneco do fundo
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * rim * 0.25;
}
