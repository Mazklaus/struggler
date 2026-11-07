shader_type canvas_item;
// Premier plan : la forme de l'objet seule, en encre presque noire, floue (trop près pour que
// l'œil fasse le point). Un léger reflet de la couleur d'origine garde un peu de volume.
uniform vec4 c_encre : source_color = vec4(0.11, 0.08, 0.13, 1.0);
uniform float flou = 2.2;

void fragment() {
	vec4 t = textureLod(TEXTURE, UV, flou);
	vec3 col = mix(c_encre.rgb * 0.55, t.rgb * 0.25, 0.25);
	COLOR = vec4(col, t.a * 0.96 * COLOR.a);   // COLOR.a : modulate (effacement devant Wendel)
}
