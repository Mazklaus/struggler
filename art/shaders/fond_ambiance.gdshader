shader_type canvas_item;
// Fond d'une ambiance : fondu entre modules voisins (voir fondu_module) et masque d'ambiance.
// Le masque est lu en coordonnées du monde : la frontière reste collée aux blocs même quand le
// fond défile en parallaxe.
// Ambiance d'intérieur : rouge du masque = part d'intérieur (forme du bord), vert = part de
// cette ambiance parmi les intérieurs. Le bord est déchiré par un bruit étiré en hauteur
// (racines, mousse, étais qui pendent), cerné d'encre comme une découpe, et la lumière du
// dehors déborde un peu à l'intérieur — comme une bouche de grotte dans Silksong.
uniform float fondu = 0.0;
uniform float fondu_x = 0.0;
uniform bool vertical = true;
uniform bool use_mask = false;
uniform sampler2D mask : filter_linear;
uniform vec4 room_rect;          // origine (xy) et taille (zw) de la salle dans le monde
uniform bool unie = false;        // pour la brume (ColorRect) : sa couleur, sans texture
uniform bool interieur = false;
uniform float flou = 0.0;         // flou de profondeur (niveau de mipmap)
uniform vec4 c_encre : source_color = vec4(0.11, 0.08, 0.13, 1.0);
uniform vec4 c_lumiere : source_color = vec4(0.95, 0.66, 0.4, 1.0);
uniform vec4 voile_c : source_color = vec4(0.54, 0.33, 0.38, 1.0);   // couleur de l'air (couches)
uniform float voile_k = 0.0;      // part de cette couleur mêlée à la couche

varying vec2 world;
varying vec4 vcol;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vcol = COLOR;
}

void fragment() {
	vec4 c = COLOR;   // déjà texture × modulate
	if (!unie && flou > 0.0) c = textureLod(TEXTURE, UV, flou) * vcol;
	if (!unie) c.rgb = mix(c.rgb, voile_c.rgb, voile_k);
	float along = vertical ? UV.y : UV.x;
	float across = vertical ? UV.x : UV.y;
	if (!unie) {
		if (fondu > 0.0) c.a *= smoothstep(0.0, fondu, along);
		if (fondu_x > 0.0) c.a *= smoothstep(0.0, fondu_x, across);
	}
	if (use_mask) {
		vec2 uv = (world - room_rect.xy) / room_rect.zw;
		vec4 m = texture(mask, clamp(uv, vec2(0.0), vec2(1.0)));
		if (interieur) {
			// Bord déchiré : brins verticaux + grandes ondulations.
			float n = (vnoise(world * vec2(0.085, 0.011)) - 0.5) * 0.30
				+ (vnoise(world * 0.022 + 17.0) - 0.5) * 0.22;
			float s = m.r + n;
			float a = smoothstep(0.46, 0.5, s) * pow(m.g, 0.6);
			if (!unie) {
				// Contour d'encre juste à l'intérieur du bord, puis la lumière du dehors qui déborde.
				float lip = smoothstep(0.5, 0.52, s) * (1.0 - smoothstep(0.55, 0.6, s));
				float bleed = 1.0 - smoothstep(0.52, 0.85, s);
				c.rgb = mix(c.rgb, c.rgb + c_lumiere.rgb * 0.45, bleed);
				c.rgb = mix(c.rgb, c_encre.rgb, smoothstep(0.46, 0.5, s) * (1.0 - smoothstep(0.5, 0.53, s)) * 0.0 + lip * 0.92);
			}
			c.a *= a;
		} else {
			c.a *= m.r;
		}
	}
	COLOR = c;
}
