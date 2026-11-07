shader_type canvas_item;
// Bourrelet de premier plan : la matière du sol, réduite à ses valeurs et teinte d'encre et
// d'ombre (couleurs des sommets), floue comme tout ce qui est trop près de l'œil.
uniform float flou = 2.0;
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 t = textureLod(TEXTURE, UV, flou);
	float v = dot(t.rgb, vec3(0.3, 0.5, 0.2));
	COLOR = vec4(vcol.rgb * (0.45 + v * 1.1), 0.97);
}
