shader_type canvas_item;
// Convierte un sprite en "estatua de piedra" y lo hace brillar (para la intro).
//   piedra = 1: todo de piedra gris | 0: colores normales
//   brillo = 1: blanco total (el rayo) | 0: normal

uniform float piedra : hint_range(0.0, 1.0) = 1.0;
uniform float brillo : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tono = vec3(0.74, 0.73, 0.67);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 roca = clamp(tono * (0.42 + l * 1.15), 0.0, 1.0);
	c.rgb = mix(c.rgb, roca, piedra);
	c.rgb = mix(c.rgb, vec3(1.0, 0.97, 0.88), brillo);
	COLOR = c;
}
