shader_type canvas_item;
// Module de fond qui se fond dans ses voisins : bande de tête (le module d'avant dans l'axe)
// et bande de côté (la colonne d'avant). Les deux sont en part de la taille du module.
uniform float fondu = 0.15;
uniform float fondu_x = 0.0;
uniform bool vertical = true;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float along = vertical ? UV.y : UV.x;
	float across = vertical ? UV.x : UV.y;
	if (fondu > 0.0) c.a *= smoothstep(0.0, fondu, along);
	if (fondu_x > 0.0) c.a *= smoothstep(0.0, fondu_x, across);
	COLOR = c;
}
