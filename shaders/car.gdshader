shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Carros (modelos do Car Kit da Kenney, CC0): paleta da textura com cores mais sóbrias.
// COLOR.r = parte pintada (cor vem de "paint"). Os carros não têm vidro.
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 paint : source_color = vec3(0.5, 0.1, 0.08);
uniform float dirt = 0.25;     // poeira de guerra
uniform float rust = 0.0;      // carcaça abandonada: ferrugem
varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = VERTEX;
	wnrm = NORMAL;
}

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 base = mix(vec3(l), c, 0.45) * 0.8;
	float rough = 0.75;
	float spec = 0.3;
	if (COLOR.r > 0.5) {
		// tinta: mantém o degradê da paleta como sombreado
		base = paint * (0.55 + 0.6 * l);
		rough = 0.38;
		spec = 0.55;
	}
	float n = vnoise(wpos.xz * 4.0 + wpos.y * 3.0) * 0.6 + vnoise(wpos.xy * 11.0) * 0.4;
	// poeira mais forte embaixo e nas laterais
	float low = 1.0 - smoothstep(0.1, 0.9, wpos.y);
	float d = clamp(dirt * (0.5 + low) * n * 1.4, 0.0, 0.8);
	base = mix(base, vec3(0.42, 0.36, 0.28), d);
	rough = mix(rough, 0.95, d);
	if (rust > 0.0) {
		float r = smoothstep(0.35, 0.75, (vnoise(wpos.xy * 6.0) * 0.5 + vnoise(wpos.zy * 6.0 + 7.0) * 0.5 + vnoise(wpos.xz * 6.0 + 3.0) * 0.3)) * rust;
		base = mix(base, vec3(0.32, 0.17, 0.08) * (0.7 + 0.5 * n), r);
		rough = mix(rough, 1.0, r);
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
