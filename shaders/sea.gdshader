shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// Mar em volta da ilha: opaco e barato (sem transparência nem reflexo), ondinhas só na cor.
// Longe ele vira a cor do horizonte do céu (não aparece a "beirada" do mar nem uma faixa no horizonte).
uniform vec3 horizon : source_color = vec3(0.7, 0.76, 0.82);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float w = sin(p.x * 0.35 + TIME * 0.9) * sin(p.y * 0.3 - TIME * 0.7);
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	vec3 deep = vec3(0.13, 0.22, 0.26);
	vec3 sky = vec3(0.5, 0.6, 0.66);
	vec3 c = mix(deep, sky, fres * 0.85) * (1.0 + w * 0.05);
	float d = length(VERTEX);
	ALBEDO = mix(c, horizon, smoothstep(120.0, 900.0, d));
}
