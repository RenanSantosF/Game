shader_type sky;

// Céu barato pro celular: só um degradê (as mesmas cores do céu de antes), sem cálculo de sol.
uniform vec3 top : source_color = vec3(0.3, 0.45, 0.66);
uniform vec3 horizon : source_color = vec3(0.72, 0.78, 0.84);
uniform vec3 ground : source_color = vec3(0.7, 0.76, 0.82);
uniform float curve = 0.18;

void sky() {
	float y = EYEDIR.y;
	if (y > 0.0) {
		// mesma curva do céu procedural: perto do horizonte claro, sobe pro azul
		float v = 1.0 - acos(clamp(y, 0.0, 1.0)) / 1.5707963;
		float k = clamp(1.0 - pow(1.0 - v, 1.0 / curve), 0.0, 1.0);
		COLOR = mix(horizon, top, k);
	} else {
		COLOR = mix(horizon, ground, clamp(-y * 20.0, 0.0, 1.0));
	}
}
