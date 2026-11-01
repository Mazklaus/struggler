shader_type canvas_item;
// Blocs de la salle en « Encre et couleur » : matière près de la surface, ombre teintée (jamais noire)
// vers l'intérieur, hachures croisées dans la profondeur, liseré de lumière sur les dessus,
// contour d'encre irrégulier. La forme vient d'une carte de distance calculée à la construction.

uniform sampler2D dist_tex : filter_linear, repeat_disable;   // distance à l'air (0 = air)
uniform sampler2D mat_tex : filter_nearest, repeat_disable;   // matière de chaque case (0 = air)
uniform sampler2D t_roche : repeat_enable, filter_linear_mipmap;
uniform sampler2D t_bois : repeat_enable, filter_linear_mipmap;
uniform sampler2D t_maconnerie : repeat_enable, filter_linear_mipmap;
uniform sampler2D t_chair : repeat_enable, filter_linear_mipmap;
uniform sampler2D t_eboulis : repeat_enable, filter_linear_mipmap;
uniform sampler2D t_fer : repeat_enable, filter_linear_mipmap;
uniform vec2 room_size = vec2(1280.0, 704.0);
uniform float max_dist = 384.0;
uniform float tex_px = 256.0;          // une répétition de texture = 8 tuiles
uniform vec4 c_encre : source_color = vec4(0.11, 0.08, 0.13, 1.0);
uniform vec4 c_ombre : source_color = vec4(0.23, 0.16, 0.27, 1.0);
uniform vec4 c_lumiere : source_color = vec4(0.95, 0.66, 0.4, 1.0);
uniform float night = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
// Un trait de hachure : lignes parallèles d'angle a, espacées de sp px, tremblées à la main.
float hatch(vec2 p, float a, float sp, float wd) {
	p += vec2(vnoise(p * 0.05), vnoise(p.yx * 0.05)) * 3.0;
	float v = dot(p, vec2(cos(a), sin(a))) / sp;
	float f = abs(fract(v) - 0.5);
	float broken = step(0.18, vnoise(vec2(floor(v), dot(p, vec2(-sin(a), cos(a))) * 0.04)));
	return (1.0 - smoothstep(wd, wd + 0.1, f)) * broken;
}
// La texture ne donne que le détail (ses valeurs) ; la couleur vient de la matière et de la palette
// de la salle. Ainsi n'importe quelle texture s'accorde à l'heure et à la zone.
vec3 matiere(float m, vec2 uv) {
	int i = int(round(m * 255.0 / 32.0)) - 1;
	vec3 t; vec3 base;
	vec3 roche = mix(c_ombre.rgb, c_lumiere.rgb, 0.24) * 0.9;
	if (i == 1) { t = texture(t_bois, uv).rgb; base = vec3(0.56, 0.37, 0.22); }
	else if (i == 2) { t = texture(t_maconnerie, uv).rgb; base = mix(vec3(0.58, 0.52, 0.46), roche, 0.3); }
	else if (i == 3) { t = texture(t_chair, uv).rgb; base = vec3(0.62, 0.17, 0.16); }
	else if (i == 4) { t = texture(t_eboulis, uv).rgb; base = mix(roche, vec3(0.5, 0.46, 0.42), 0.35); }
	else if (i == 5) { t = texture(t_fer, uv).rgb; base = vec3(0.34, 0.37, 0.42); }
	else { t = texture(t_roche, uv).rgb; base = roche; }
	float l = dot(t, vec3(0.299, 0.587, 0.114));
	l = clamp((l - 0.25) * 1.6 + 0.5, 0.0, 1.0);          // détail contrasté autour du milieu
	return base * (0.45 + 0.85 * l);
}

void fragment() {
	vec2 w = UV * room_size;
	float d = texture(dist_tex, UV).r * max_dist;
	float edge = d - 4.0 + (vnoise(w * 0.07) - 0.5) * 6.0;
	if (edge < 0.0) discard;

	vec3 col = matiere(texture(mat_tex, UV).r, w / tex_px);

	// Vers l'intérieur : la matière s'efface dans l'ombre teintée ; les hachures font la transition,
	// puis le cœur des blocs reste un aplat sombre, calme, qui laisse lire les plateformes.
	float depth = clamp(edge / 140.0, 0.0, 1.0);
	vec3 deep = mix(c_ombre.rgb, c_encre.rgb, 0.45);
	col = mix(col, c_ombre.rgb, smoothstep(0.05, 0.55, depth) * 0.8);
	col = mix(col, deep, smoothstep(0.5, 1.0, depth));
	float band = smoothstep(0.06, 0.25, depth) * (1.0 - smoothstep(0.55, 0.9, depth));
	float h1 = hatch(w, 0.79, 7.0, 0.12) * band;
	float h2 = hatch(w, -0.79, 9.0, 0.10) * band * smoothstep(0.2, 0.45, depth);
	col = mix(col, c_encre.rgb, clamp(h1 * 0.6 + h2 * 0.45, 0.0, 0.8));

	// Liseré de lumière sur les dessus (l'air est au-dessus quand la distance croît vers le bas).
	vec2 px = 1.0 / vec2(textureSize(dist_tex, 0));
	float gy = texture(dist_tex, UV + vec2(0.0, px.y)).r - texture(dist_tex, UV - vec2(0.0, px.y)).r;
	float rim = smoothstep(0.0, 0.01, gy) * (1.0 - smoothstep(4.0, 11.0, edge));
	col = mix(col, c_lumiere.rgb, rim * 0.55 * (1.0 - night * 0.6));

	// Contour d'encre, d'épaisseur irrégulière.
	float ink = 1.0 - smoothstep(2.2, 3.6, edge + (vnoise(w * 0.25) - 0.5) * 2.0);
	col = mix(col, c_encre.rgb, ink);
	COLOR = vec4(col, 1.0);
}
