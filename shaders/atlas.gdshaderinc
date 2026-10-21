// Atlas 4x4 numa textura comum (funciona em qualquer celular).
// Cada camada tem 512 px de imagem + 16 px de borda repetida.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;

vec3 atlas_sample(vec2 uv, float layer) {
	float l = floor(layer + 0.5);
	vec2 cell = vec2(mod(l, 4.0), floor(l / 4.0));
	vec2 inner = (fract(uv) * 512.0 + 16.0) / 544.0;
	vec2 g = vec2(512.0 / 2176.0);
	return textureGrad(tex, (cell + inner) * 0.25, dFdx(uv) * g, dFdy(uv) * g).rgb;
}
