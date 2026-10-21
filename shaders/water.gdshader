shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx, shadows_disabled;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec2 p = wpos.xz;
	float a = sin(p.x * 0.9 + t * 1.1) * 0.5 + sin(p.y * 1.3 - t * 0.8) * 0.5 + sin((p.x + p.y) * 2.1 + t * 1.7) * 0.25;
	float b = cos(p.y * 0.8 + t * 1.2) * 0.5 + cos(p.x * 1.5 - t * 0.9) * 0.5;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(a * 0.05, 0.0, b * 0.05, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(vec3(0.05, 0.1, 0.09), vec3(0.35, 0.45, 0.5), fres);
	ALPHA = mix(0.78, 0.95, fres);
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
}
