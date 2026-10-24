shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

// Velame do paraquedas: nylon brilhante (reflexo), ondulado e tremendo com o vento.
// UV.x = ao longo da envergadura (0..células), UV.y = da frente (0) pra trás (1); UV2.x = 1 nas cordas.
uniform float cells = 9.0;
varying float is_line;
varying float chord;
varying float under;

void vertex() {
	is_line = UV2.x;
	chord = UV.y;
	under = UV2.y;
	if (is_line < 0.5) {
		// bordo de fuga treme mais que a frente; a onda corre pela envergadura
		float w = sin(TIME * 7.5 + UV.x * 2.1) * 0.035 + sin(TIME * 13.0 + UV.x * 5.3 + UV.y * 3.0) * 0.012;
		VERTEX.y += w * smoothstep(0.35, 1.0, UV.y) * 1.6;
		VERTEX.z += sin(TIME * 5.0 + UV.x * 1.3) * 0.02 * UV.y;
	}
	COLOR.rgb = pow(COLOR.rgb, vec3(2.2));
}

void fragment() {
	vec3 base = COLOR.rgb;
	if (is_line > 0.5) {
		ALBEDO = base;
		ROUGHNESS = 0.8;
		SPECULAR = 0.2;
	} else {
		// costuras entre as células e rugas do tecido (ondas finas no sentido da corda)
		float edge = smoothstep(0.47, 0.5, abs(fract(UV.x) - 0.5));
		float wr = sin(UV.y * 40.0 + sin(UV.x * 9.0) * 2.0) * 0.5 + 0.5;
		float wr2 = sin(UV.x * 31.0 + UV.y * 7.0) * 0.5 + 0.5;
		base *= 0.9 + 0.1 * wr * wr2;
		base *= 1.0 - edge * 0.35;
		// costura da frente e de trás mais escura
		base *= 1.0 - (1.0 - smoothstep(0.0, 0.03, UV.y)) * 0.3 - smoothstep(0.97, 1.0, UV.y) * 0.25;
		ALBEDO = base;
		// embaixo o sol atravessa o tecido (fica colorido, não preto)
		EMISSION = base * (0.12 + 0.3 * under);
		// nylon: brilho forte, meio liso
		ROUGHNESS = 0.32 + 0.12 * wr;
		SPECULAR = 0.75;
		// relevo das rugas na luz
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(0.0, (wr - 0.5) * 0.12, (wr2 - 0.5) * 0.08, 0.0)).xyz);
	}
}
