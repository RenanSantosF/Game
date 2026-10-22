shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Item no chão: igual ao material do mundo, com um brilho suave pulsando na cor da raridade
// (borda acesa + leve luz própria) pra achar o item sem poluir a tela.
#include "res://shaders/atlas.gdshaderinc"
uniform vec3 glow : source_color = vec3(1.0);
uniform float strength = 0.6;

varying float layer;

void vertex() {
	layer = UV2.x;
	COLOR.rgb = pow(COLOR.rgb, vec3(2.2));
}

void fragment() {
	vec3 t = atlas_sample(UV, layer);
	ALBEDO = t * COLOR.rgb;
	ROUGHNESS = 0.7;
	SPECULAR = 0.4;
	float pulse = 0.65 + 0.35 * sin(TIME * 3.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = glow * (0.18 + rim * 1.1) * pulse * strength;
}
