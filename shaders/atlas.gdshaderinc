// Atlas 4x4 numa textura comum (funciona em qualquer celular).
// Cada camada tem 1024 px de imagem + 32 px de borda repetida (tools/atlas_photo.py).
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;

vec3 atlas_sample(vec2 uv, float layer) {
	float l = floor(layer + 0.5);
	vec2 cell = vec2(mod(l, 4.0), floor(l / 4.0));
	vec2 inner = (fract(uv) * 1024.0 + 32.0) / 1088.0;
	vec2 g = vec2(1024.0 / 4352.0);
	return textureGrad(tex, (cell + inner) * 0.25, dFdx(uv) * g, dFdy(uv) * g).rgb;
}

// mesma leitura, com as derivadas calculadas fora (pode ser chamada dentro de if)
vec3 atlas_sample_g(vec2 uv, float layer, vec2 dx, vec2 dy) {
	float l = floor(layer + 0.5);
	vec2 cell = vec2(mod(l, 4.0), floor(l / 4.0));
	vec2 inner = (fract(uv) * 1024.0 + 32.0) / 1088.0;
	vec2 g = vec2(1024.0 / 4352.0);
	return textureGrad(tex, (cell + inner) * 0.25, dx * g, dy * g).rgb;
}
