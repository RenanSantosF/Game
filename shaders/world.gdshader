shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Material de quase tudo: textura do atlas (camada em UV2.x) vezes a cor do vértice.
// UV2.y > 0 = balança com o vento (folhas).
uniform sampler2DArray tex : source_color, filter_linear_mipmap, repeat_enable;

varying float layer;

void vertex() {
	layer = UV2.x;
	COLOR.rgb = pow(COLOR.rgb, vec3(2.2));
	if (UV2.y > 0.0) {
		vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float s = sin(TIME * 1.3 + w.x * 0.11 + w.z * 0.07) * UV2.y * max(VERTEX.y - 2.0, 0.0) * 0.012;
		VERTEX.x += s;
		VERTEX.z += s * 0.6;
	}
}

void fragment() {
	vec3 t = texture(tex, vec3(UV, floor(layer + 0.5))).rgb;
	ALBEDO = t * COLOR.rgb;
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}
