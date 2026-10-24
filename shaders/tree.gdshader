shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled, vertex_lighting;

// Árvores em MultiMesh: tronco e folhas de cada tipo de árvore numa superfície só (antes eram 2
// chamadas de desenho por bloco). Por vértice: UV2.y = 1 no tronco.
// O tronco usa uma leitura de textura só (antes eram 3, projeção "triplanar").
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D trunk_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.9;
uniform float scissor = 0.45;

varying vec3 lpos;
varying vec3 lnrm;
varying float is_trunk;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	is_trunk = UV2.y;
}

void fragment() {
	vec3 an = abs(lnrm);
	vec2 tuv = (an.y > 0.7 ? lpos.xz : (an.x > an.z ? lpos.zy : lpos.xy)) * uv_scale;
	vec2 uv = is_trunk > 0.5 ? tuv : UV;
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec4 t;
	if (is_trunk > 0.5) {
		t = vec4(textureGrad(trunk_tex, uv, dx, dy).rgb, 1.0);
	} else {
		t = textureGrad(leaf_tex, uv, dx, dy);
	}
	ALBEDO = t.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
