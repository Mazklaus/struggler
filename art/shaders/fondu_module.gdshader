shader_type canvas_item;
// Module de fond qui se fond dans le précédent sur sa bande de tête (raccord entre variantes).
uniform float fondu = 0.15;   // part de la hauteur du module (0 = pas de fondu)

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float v = fract(UV.y);
	c.a *= fondu > 0.0 ? smoothstep(0.0, fondu, v) : 1.0;
	COLOR = c;
}
