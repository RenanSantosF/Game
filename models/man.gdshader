shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Personagem com textura (models/man_albedo.png). Cada jogador tem a sua cor de jaqueta e de calça:
// a máscara (models/man_mask.png, R = jaqueta, G = calça, feita pelo tools/man_mask.py) diz onde
// trocar a cor; o claro/escuro do tecido continua o da textura. Pele, rosto e cabelo ficam como estão.

uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform sampler2D mask : hint_default_black, filter_linear_mipmap;
uniform vec3 c_shirt : source_color = vec3(0.3, 0.35, 0.25);
uniform vec3 c_pants : source_color = vec3(0.25, 0.27, 0.3);
uniform vec3 c_skin : source_color = vec3(0.78, 0.58, 0.45);
uniform float tint = 1.0;

// brilho médio (linear) da jaqueta e do jeans na textura
const float JK_LUM = 0.0601;
const float JN_LUM = 0.0285;

float lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

void fragment() {
	vec3 c = texture(albedo, UV).rgb;
	vec2 m = texture(mask, UV).rg * tint;
	float l = lum(c);
	c = mix(c, c_shirt * 0.85 * min(l / JK_LUM, 1.8), m.r);
	c = mix(c, c_pants * 0.85 * min(l / JN_LUM, 1.8), m.g);
	// pele: laranja claro fora da roupa (puxa o tom pra cor do jogador)
	vec3 t0 = texture(albedo, UV).rgb;
	float sk = step(t0.g * 1.7, t0.r) * step(t0.b * 1.2, t0.g) * smoothstep(0.15, 0.3, lum(t0)) * (1.0 - m.r - m.g);
	c = mix(c, c * (c_skin / vec3(0.6, 0.31, 0.2)), sk * 0.7);
	ALBEDO = c;
	ROUGHNESS = mix(0.9, 0.6, sk);
	SPECULAR = mix(0.15, 0.35, sk);
	// borda iluminada: destaca o boneco do fundo
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * rim * 0.15;
}
