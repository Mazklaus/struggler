shader_type canvas_item;
// Fond d'une ambiance : fondu entre modules voisins (voir fondu_module) et masque d'ambiance.
// Le masque est une image de la salle à une case par pixel (blanc = cette ambiance), adoucie
// pour que deux ambiances voisines se fondent sur quelques cases. Il est lu en coordonnées du
// monde : la frontière reste collée aux blocs même quand le fond défile en parallaxe.
uniform float fondu = 0.0;
uniform float fondu_x = 0.0;
uniform bool vertical = true;
uniform bool use_mask = false;
uniform sampler2D mask : filter_linear;
uniform vec4 room_rect;          // origine (xy) et taille (zw) de la salle dans le monde
uniform bool unie = false;        // pour la brume (ColorRect) : sa couleur, sans texture

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;   // déjà texture × modulate
	float along = vertical ? UV.y : UV.x;
	float across = vertical ? UV.x : UV.y;
	if (!unie) {
		if (fondu > 0.0) c.a *= smoothstep(0.0, fondu, along);
		if (fondu_x > 0.0) c.a *= smoothstep(0.0, fondu_x, across);
	}
	if (use_mask) {
		vec2 uv = (world - room_rect.xy) / room_rect.zw;
		c.a *= texture(mask, clamp(uv, vec2(0.0), vec2(1.0))).r;
	}
	COLOR = c;
}
