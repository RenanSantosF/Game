shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Carros (tools/prepare_cars2.gd): cor da textura original no vértice; UV2.x = 1 marca a pintura
// (cada carro com sua cor, vem de "paint"). Os carros não têm vidro.
uniform vec3 paint : source_color = vec3(0.5, 0.1, 0.08);
uniform float dirt = 0.25;     // poeira de guerra
uniform float rust = 0.0;      // carcaça abandonada: ferrugem
varying vec3 wpos;
varying vec3 wnrm;
varying float painted;

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
	painted = UV2.x;
	COLOR.rgb = pow(COLOR.rgb, vec3(2.2));
}

void fragment() {
	vec3 base = COLOR.rgb;
	float rough = 0.75;
	float spec = 0.3;
	if (painted > 0.5) {
		base = paint;
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
