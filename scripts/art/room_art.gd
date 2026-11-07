class_name RoomArt
extends Node2D
## Habillage « Encre et couleur » d'une salle : fond peint en parallaxe, brume, blocs à l'encre,
## halos de lumière. Se greffe sur une Room déjà construite sans rien changer à son gameplay :
## les collisions, ennemis et objets restent ceux de la salle grise.

const CELL := 4.0            # résolution de la carte des blocs (8 cases par tuile)
const MAX_CELLS := 64        # distance maximale mesurée vers l'intérieur des blocs
const MAT_INDEX := {"roche": 0, "bois": 1, "maconnerie": 2, "chair": 3, "eboulis": 4, "fer": 5}

var room: Room
var conf := {}
var dir := ""
var _blocks: ColorRect
var amb_map := PackedStringArray()   # ambiance de chaque case (ligne par ligne), voir ambiance_map
var _amb_w := 0
var _solid_tiles := PackedByteArray()
const SUB := 4   # sous-cases par case dans le masque des intérieurs
var _maps_task := -1
var _maps: Array = []
var _on := true
var _saved_solids: Array[Rect2] = []
var _saved_labels: Array = []


func setup(r: Room, zone_dir: String, zone: Dictionary, salle: Dictionary) -> void:
	room = r
	dir = zone_dir
	conf = salle
	name = "RoomArt"
	z_index = -10
	z_as_relative = false
	# Fonds, modules et décors sont réduits à l'écran : mipmaps pour éviter le crénelage.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ambs: Dictionary = zone.get("ambiances", {})
	var main: Dictionary = ambs.get(salle.get("ambiance", ""), salle)
	var pal: Dictionary = salle.get("palette", main.get("palette", {}))
	_build_fonds(zone, salle, main)

	_blocks = ColorRect.new()
	_blocks.size = room.size
	_blocks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://art/shaders/encre_blocs.gdshader")
	# Les cartes des blocs se calculent sur un autre fil, pendant le fondu d'entrée de salle :
	# la salle grise reste affichée jusqu'à ce qu'elles soient prêtes, sans à-coup.
	var solids := room.solids.duplicate()
	var mats := room.solid_mats.duplicate()
	var sz := room.size
	_maps_task = WorkerThreadPool.add_task(func(): _maps = _block_maps(solids, mats, sz))
	_blocks.visible = false
	mat.set_shader_parameter("room_size", room.size)
	mat.set_shader_parameter("max_dist", MAX_CELLS * CELL)
	for k in MAT_INDEX:
		var path: String = zone.get("matieres", {}).get(k, "")
		if path != "":
			mat.set_shader_parameter("t_" + k, load(dir + path))
	for k in ["encre", "ombre", "lumiere"]:
		if pal.has(k):
			mat.set_shader_parameter("c_" + k, Color(pal[k]))
	_blocks.material = mat
	add_child(_blocks)

	# Objets de décor posés sur le sol (derrière Wendel, ou devant avec « devant »).
	for dc in salle.get("decors", []):
		var sp := Sprite2D.new()
		sp.texture = load(dir + dc.image)
		# Taille réelle en mètres (1 case = 1 m) ; « echelle » reste accepté pour un réglage brut.
		var k: float = float(dc.hauteur) * Room.TILE / sp.texture.get_height() if dc.has("hauteur") else float(dc.get("echelle", 0.5))
		sp.scale = Vector2(k, k)
		if dc.get("miroir", false):
			sp.scale = Vector2(-k, k)
		sp.centered = true
		sp.offset = Vector2(0, -sp.texture.get_height() * 0.5)
		sp.position = Vector2(float(dc.x) * Room.TILE, float(dc.y) * Room.TILE + 4.0)
		sp.z_index = 40 if dc.get("devant", false) else -12
		sp.set_meta("decor_m", float(sp.texture.get_height()) * k / Room.TILE)
		# Teinté par la lumière de la salle, pour qu'il ne paraisse pas collé.
		sp.modulate = Color.WHITE.lerp(Color(pal.get("lumiere", "ffffff")), 0.35)
		add_child(sp)
		if dc.get("lumiere", false):
			_glow(sp.position + Vector2(0, -sp.texture.get_height() * k * 0.3), Color(pal.get("lumiere", "ffaa66")), 1.6)

	_build_premier_plan(salle, pal)
	if salle.has("bourrelet"):
		_build_bourrelet(salle.bourrelet, zone, pal)

	# Halos chauds sur les brasiers et cercles de sel.
	for rs in room.rests:
		_glow((rs.rect as Rect2).get_center(), Color(pal.get("lumiere", "ffaa66")), 2.2)
	apply(true)


## Premier plan : silhouettes d'encre floues, devant Wendel, qui défilent plus vite que le jeu
## (comme les tiges et rochers sombres au bas de l'écran dans Silksong).
var _pp: Array = []

func _build_premier_plan(salle: Dictionary, pal: Dictionary) -> void:
	var sh: Shader = load("res://art/shaders/premier_plan.gdshader")
	for d in salle.get("premier_plan", []):
		var sp := Sprite2D.new()
		sp.texture = load(dir + d.image)
		var k: float = float(d.get("hauteur", 3.0)) * Room.TILE / sp.texture.get_height()
		sp.scale = Vector2(-k if d.get("miroir", false) else k, k)
		sp.centered = true
		sp.offset = Vector2(0, -sp.texture.get_height() * 0.5)
		sp.z_index = 60
		sp.z_as_relative = false
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("c_encre", Color(pal.get("encre", "1d1420")))
		m.set_shader_parameter("flou", float(d.get("flou", 2.2)))
		sp.material = m
		add_child(sp)
		_pp.append([sp, Vector2(float(d.x) * Room.TILE, float(d.y) * Room.TILE), float(d.get("parallaxe", 1.15))])


## Bourrelet de premier plan : le sol de la salle lui-même, prolongé devant la caméra. Son profil
## suit le dessus du sol (case par case, y compris les fosses), passe juste sous la ligne où l'on
## marche et ne se lève qu'en quelques bosses — plus hautes aux passages dedans/dehors, pour les
## cadrer. Même matière que le sol, en encre et ombre de la palette, flou. Défile à la parallaxe
## « parallaxe » (1,15) : il glisse plus vite que le jeu, comme les rochers au bas de l'écran
## dans Silksong. Rien à dessiner : il se recalcule quand la salle change de forme.
var _bour: Node2D
var _ciel_name := ""
var _bour_f := 1.15

func _build_bourrelet(b: Dictionary, zone: Dictionary, pal: Dictionary) -> void:
	var rows: Array = Rooms.DATA[room.id].rows
	var w: int = rows[0].length()
	var h: int = rows.size()
	var T := float(Room.TILE)
	_bour_f = float(b.get("parallaxe", 1.15))
	var sol_y := PackedFloat32Array()
	var sol_m := PackedStringArray()
	sol_y.resize(w)
	sol_m.resize(w)
	for x in w:
		var y := h - 1
		while y > 0 and (rows[y] as String)[x] in "#XwbMota^":
			y -= 1
		var top := y + 1
		sol_y[x] = float(top) if top < h else float(h)
		sol_m[x] = Room.MATS.get((rows[mini(top, h - 1)] as String)[x], "roche")
	# Passages dedans/dehors le long du sol : là où la part d'intérieur franchit 1/2 juste
	# au-dessus du sol.
	var portes: Array[float] = []
	if not amb_map.is_empty() and _amb_w == w:
		var prev := -1.0
		for x in w:
			var yy := clampi(int(sol_y[x]) - 2, 0, h - 1)
			var inside := 0.0 if amb_map[yy * w + x] == _ciel_name else 1.0
			if prev >= 0.0 and inside != prev:
				portes.append(float(x))
			prev = inside
	var seed := float(hash(room.id) % 1000)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var lit := Color(pal.get("ombre", "3a2a44"))
	var ink := Color(pal.get("encre", "1d1420"))
	var step := 0.25
	var x := 0.0
	while x <= w:
		var xi := clampi(int(x), 0, w - 1)
		var base := sol_y[xi]
		# Le gros du bourrelet reste sous la ligne du sol ; il n'en sort que par amas (bruit lent),
		# plus haut près d'un passage dedans/dehors, avec un bord cassé d'éboulis.
		var n := sin(x * 0.37 + seed) * 0.5 + sin(x * 0.11 + seed * 1.7) * 0.8 + sin(x * 0.83 + seed * 0.3) * 0.3
		var bump := maxf(0.0, n - 0.35) * 2.4
		for p in portes:
			bump = maxf(bump, 3.0 * exp(-pow((x - p) / 2.2, 2.0)) + maxf(0.0, n) * 0.4)
		# jamais plus haut qu'environ 1,4 m au-dessus du sol : il ne doit pas cacher Wendel
		bump = minf(bump, 3.0) + sin(x * 2.7 + seed) * 0.14 + sin(x * 6.1 + seed * 2.0) * 0.07
		# Le sol voisin, lissé : les bords d'une fosse descendent en pente, pas à pic.
		var bl := (sol_y[maxi(xi - 1, 0)] + base * 2.0 + sol_y[mini(xi + 1, w - 1)]) / 4.0
		var y := (bl + 1.6 - bump) * T
		pts.append(Vector2(x * T, y))
		cols.append(lit.lerp(ink, 0.35))
		x += step
	var bottom := float(h) * T + 400.0
	pts.append(Vector2(float(w) * T, bottom))
	cols.append(ink)
	pts.append(Vector2(0.0, bottom))
	cols.append(ink)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.vertex_colors = cols
	var mname: String = b.get("matiere", "")
	if mname == "":
		var count := {}
		for m in sol_m:
			count[m] = count.get(m, 0) + 1
		var best := 0
		for m in count:
			if count[m] > best:
				best = count[m]
				mname = m
	var tpath: String = zone.get("matieres", {}).get(mname, "")
	if tpath != "":
		poly.texture = load(dir + tpath)
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var uv := PackedVector2Array()
		for q in pts:
			uv.append(q * 1.6)
		poly.uv = uv
	var m := ShaderMaterial.new()
	m.shader = load("res://art/shaders/bourrelet.gdshader")
	m.set_shader_parameter("flou", float(b.get("flou", 2.0)))
	poly.material = m
	_bour = Node2D.new()
	_bour.z_index = 60
	_bour.z_as_relative = false
	_bour.add_child(poly)
	add_child(_bour)


func _update_premier_plan() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position() - room.global_position
	if _bour:
		# Chaque point p du bourrelet s'affiche en p + (p - c)(f - 1) = f·p - (f - 1)·c.
		_bour.scale = Vector2(_bour_f, _bour_f)
		_bour.position = -c * (_bour_f - 1.0)
	for e in _pp:
		var base: Vector2 = e[1]
		(e[0] as Sprite2D).position = base + (base - c) * (float(e[2]) - 1.0)


func _glow(at: Vector2, c: Color, size: float) -> void:
		var glow := Sprite2D.new()
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.width = 256
		g.height = 256
		var grad := Gradient.new()
		grad.set_color(0, Color(c, 0.55))
		grad.set_color(1, Color(c, 0.0))
		g.gradient = grad
		glow.texture = g
		glow.scale = Vector2(size, size)
		glow.position = at
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		glow.z_index = 5
		add_child(glow)


## Montre l'habillage (true) ou rend la salle grise d'origine (false).
func apply(on: bool) -> void:
	_on = on
	visible = on
	var deco := room.deco
	if on and not _blocks.visible:
		return   # cartes pas encore prêtes : les blocs gris restent en attendant
	if on:
		if _saved_solids.is_empty() and not deco.solids.is_empty():
			_saved_solids = deco.solids
			_saved_labels = deco.labels
		deco.solids = [] as Array[Rect2]
		deco.labels = []
	elif not _saved_solids.is_empty():
		deco.solids = _saved_solids
		deco.labels = _saved_labels
	deco.queue_redraw()


func _process(_delta: float) -> void:
	if _maps_task >= 0 and WorkerThreadPool.is_task_completed(_maps_task):
		WorkerThreadPool.wait_for_task_completion(_maps_task)
		_maps_task = -1
		var m := _blocks.material as ShaderMaterial
		m.set_shader_parameter("dist_tex", ImageTexture.create_from_image(_maps[0]))
		m.set_shader_parameter("mat_tex", ImageTexture.create_from_image(_maps[1]))
		_blocks.visible = true
		apply(_on)
	if visible:
		_update_premier_plan()
	if visible and _blocks.material:
		(_blocks.material as ShaderMaterial).set_shader_parameter("night", World.night_amount())


## Les fonds de la salle, un par ambiance. Une salle sans « regles » ni « zones » n'a qu'une
## ambiance. Sinon l'ambiance « ciel » (l'extérieur) couvre toute la salle, et les ambiances
## d'intérieur (sous un terril, un boisage…) se posent par-dessus. Leur bord ne suit pas les
## cases : il vient de ce qu'on voit du ciel depuis chaque case (voir _ouverture), si bien qu'une
## bouche de galerie s'ouvre en éventail sous la lèvre du bloc, avec un contour d'encre déchiré
## et la lumière du dehors qui déborde un peu dedans (voir fond_ambiance.gdshader).
func _build_fonds(zone: Dictionary, salle: Dictionary, main: Dictionary) -> void:
	var ambs: Dictionary = zone.get("ambiances", {})
	if not salle.has("regles") and not salle.has("zones"):
		_add_fond(main, null, false)
		return
	ambiance_map(salle, salle.get("ambiance", ""))
	var regles: Dictionary = salle.get("regles", {})
	var ciel: String = regles.get("ciel", salle.get("ambiance", ""))
	_ciel_name = ciel
	var used := {}
	for a in amb_map:
		used[a] = true
	if ambs.has(ciel):
		_add_fond(ambs[ciel], null, false)
	var interieur := _interieur(salle, ciel)
	for a in used:
		if a == ciel:
			continue
		if not ambs.has(a):
			push_warning("ambiance inconnue : %s (salle %s)" % [a, room.id])
			continue
		_add_fond(ambs[a], _mask_interieur(a, ciel, interieur, int(salle.get("fondu_cases", 3))), true)


func _add_fond(amb: Dictionary, mask: Texture2D, interieur: bool) -> void:
	var fc := FondCalque.new()
	add_child(fc)
	fc.setup(room, dir, amb, mask, interieur)


## Part d'« intérieur » de chaque case (0 dehors, 1 dedans) : 1 moins la part du ciel visible
## depuis la case, dans un cône de ±50° vers le haut. Sous un long terril : 1 ; à l'air libre,
## même au pied d'un mur : 0 ; sous la lèvre d'une galerie : un dégradé en éventail qui épouse
## la forme du bloc. Les « zones » forcées (une façade en plein air) comptent comme dedans.
func _interieur(salle: Dictionary, ciel: String) -> PackedFloat32Array:
	var rows: Array = Rooms.DATA[room.id].rows
	var w: int = rows[0].length()
	var h: int = rows.size()
	var top := 0
	while top < h and float((rows[top] as String).count(" ")) < w * 0.1 and top < 3:
		top += 1
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		var r: String = rows[y]
		for x in w:
			solid[y * w + x] = 1 if r[x] in "#XwbMota-" else 0
	var dirs: Array[Vector2] = []
	for k in 11:
		var ang := deg_to_rad(-50.0 + k * 10.0)
		dirs.append(Vector2(sin(ang), -cos(ang)) * 0.5)
	var v := PackedFloat32Array()
	v.resize(w * h)
	for y in h:
		for x in w:
			if solid[y * w + x] == 1:
				v[y * w + x] = 1.0
				continue
			var open := 0
			for d in dirs:
				var p := Vector2(x + 0.5, y + 0.5)
				var ok := true
				for st in 28:
					p += d
					if p.y < top:
						break
					var cx := int(p.x)
					var cy := int(p.y)
					if cx < 0 or cx >= w or cy >= h:
						ok = false
						break
					if solid[cy * w + cx] == 1:
						ok = false
						break
				if ok:
					open += 1
			v[y * w + x] = 1.0 - smoothstep(0.2, 0.6, open / 11.0)
	# Zones forcées : dedans.
	for z in salle.get("zones", []):
		if z.ambiance == ciel:
			continue
		for y in range(int(z.de[1]), int(z.a[1])):
			for x in range(int(z.de[0]), int(z.a[0])):
				if x >= 0 and x < w and y >= 0 and y < h:
					v[y * w + x] = 1.0
	# Flou entre cases d'air seulement, puis chaque bloc prend la plus petite valeur de l'air
	# juste au-dessus et juste en dessous : le dessus d'un terril reste « dehors » (pas de fond
	# d'intérieur qui dépasse dans le ciel), le dessous ne tire pas le tunnel vers le dehors.
	var air := PackedFloat32Array()
	air.resize(w * h)
	for i in w * h:
		air[i] = 0.0 if solid[i] == 1 else 1.0
		v[i] *= air[i]
	var vb := _flou_boite(v, w, h, 1)
	var ab := _flou_boite(air, w, h, 1)
	for i in w * h:
		v[i] = vb[i] / ab[i] if ab[i] > 0.01 else 0.0
	_solid_tiles = solid
	return v


func _flou_boite(v: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	for pass_ in 2:
		var o := PackedFloat32Array()
		o.resize(w * h)
		for y in h:
			for x in w:
				var s := 0.0
				var n := 0
				for d in range(-r, r + 1):
					var xx := x + d if pass_ == 0 else x
					var yy := y if pass_ == 0 else y + d
					if xx >= 0 and xx < w and yy >= 0 and yy < h:
						s += v[yy * w + xx]
						n += 1
				o[y * w + x] = s / float(n)
		v = o
	return v


## Ambiance de chaque case, d'après la forme de la salle : une case regarde ce qu'elle a
## au-dessus d'elle. Rien (hors bordure du haut) : « ciel ». Sinon la lettre du premier bloc
## rencontré (« t » terril, « b » ou « - » boisage, « M » maçonnerie…) ou « * » pour tout bloc.
## Les « zones » (rectangles en cases, de [x, y] à [x, y] exclus) passent par-dessus.
func ambiance_map(salle: Dictionary, defaut: String) -> PackedStringArray:
	var rows: Array = Rooms.DATA[room.id].rows
	var w: int = rows[0].length()
	var h: int = rows.size()
	_amb_w = w
	var regles: Dictionary = salle.get("regles", {})
	# Bordure du haut : les premières lignes presque pleines (le plafond de la salle).
	var top := 0
	while top < h and float((rows[top] as String).count(" ")) < w * 0.1 and top < 3:
		top += 1
	amb_map.resize(w * h)
	for x in w:
		var cover := ""
		for y in h:
			var ch: String = (rows[y] as String)[x]
			var solid := ch in "#XwbMota-"   # blocs et bois (voir la légende de rooms.gd)
			if y >= top and solid:
				cover = ch
			var a := defaut
			if not regles.is_empty():
				if cover == "":
					a = regles.get("ciel", defaut)
				else:
					a = regles.get(cover, regles.get("*", defaut))
			amb_map[y * w + x] = a
	for z in salle.get("zones", []):
		for y in range(int(z.de[1]), int(z.a[1])):
			for x in range(int(z.de[0]), int(z.a[0])):
				if x >= 0 and x < w and y >= 0 and y < h:
					amb_map[y * w + x] = z.ambiance
	return amb_map


func ambiance_at(cell: Vector2i) -> String:
	if _amb_w == 0:
		return ""
	return amb_map[cell.y * _amb_w + cell.x]


## Masque d'une ambiance d'intérieur, une case par pixel : rouge = part d'intérieur de la case
## (la forme du bord, commune à tous les intérieurs), vert = part de cette ambiance parmi les
## intérieurs voisins (fondu de « fondu » cases entre un tunnel et un abri, sans contour).
func _mask_interieur(a: String, ciel: String, interieur: PackedFloat32Array, fondu: int) -> Texture2D:
	var w := _amb_w
	var h := amb_map.size() / w
	var mine := PackedFloat32Array()
	var any := PackedFloat32Array()
	mine.resize(w * h)
	any.resize(w * h)
	for i in w * h:
		mine[i] = 1.0 if amb_map[i] == a else 0.0
		any[i] = 1.0 if amb_map[i] != ciel else 0.0
	var r := maxi(fondu / 2, 1)
	# Élargi d'abord (une case du dehors sous la lèvre prend l'intérieur le plus proche).
	mine = _flou_boite(mine, w, h, r + 1)
	any = _flou_boite(any, w, h, r + 1)
	# Masque à SUB pixels par case. Dans l'air : interpolation entre cases d'air seulement.
	# Dans un bloc : la valeur de l'air juste en dessous (sinon au-dessus) — la frontière tombe
	# au ras des blocs, sans fuite de ciel sous un plafond ni fond qui dépasse au-dessus.
	var sol := _solid_tiles
	var tile_v := PackedFloat32Array()
	tile_v.resize(w * h)
	for x in w:
		for y in h:
			var i := y * w + x
			if sol[i] == 0:
				tile_v[i] = interieur[i]
				continue
			var val := -1.0
			for yy in range(y + 1, h):
				if sol[yy * w + x] == 0:
					val = interieur[yy * w + x]
					break
			if val < 0.0:
				for yy in range(y - 1, -1, -1):
					if sol[yy * w + x] == 0:
						val = interieur[yy * w + x]
						break
			tile_v[i] = 1.0 if val < 0.0 else val
	var part := PackedFloat32Array()
	part.resize(w * h)
	for i in w * h:
		part[i] = clampf(mine[i] / any[i], 0.0, 1.0) if any[i] > 0.001 else 0.0
	var W := w * SUB
	var H := h * SUB
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	for fy in H:
		for fx in W:
			var tx := fx / SUB
			var ty := fy / SUB
			var ti := ty * w + tx
			var gx := (fx + 0.5) / SUB - 0.5
			var gy := (fy + 0.5) / SUB - 0.5
			var x0 := clampi(int(floor(gx)), 0, w - 1)
			var y0 := clampi(int(floor(gy)), 0, h - 1)
			var x1 := mini(x0 + 1, w - 1)
			var y1 := mini(y0 + 1, h - 1)
			var ux := clampf(gx - x0, 0.0, 1.0)
			var uy := clampf(gy - y0, 0.0, 1.0)
			var rv := 0.0
			var g := 0.0
			var sw := 0.0
			for k in 4:
				var cx := x1 if k & 1 else x0
				var cy := y1 if k & 2 else y0
				var wt := (ux if k & 1 else 1.0 - ux) * (uy if k & 2 else 1.0 - uy)
				var ci := cy * w + cx
				g += part[ci] * wt
				# dans l'air, on n'interpole qu'avec l'air ; dans un bloc, valeur du bloc
				if sol[ti] == 0 and sol[ci] == 1:
					continue
				if sol[ti] == 1 and sol[ci] == 0:
					continue
				rv += tile_v[ci] * wt
				sw += wt
			rv = rv / sw if sw > 0.0 else tile_v[ti]
			img.set_pixel(fx, fy, Color(rv, g, 0))
	return ImageTexture.create_from_image(img)


## Deux cartes de la salle à 8 px la case : distance de chaque case pleine à l'air le plus proche
## (pour l'ombre, les hachures et le contour), et matière de chaque case.
func _block_maps(solids: Array, mats: Array, sz: Vector2) -> Array:
	var gw := int(ceil(sz.x / CELL))
	var gh := int(ceil(sz.y / CELL))
	var mat := PackedByteArray()
	mat.resize(gw * gh)
	mat.fill(0)
	for i in solids.size():
		var r: Rect2 = solids[i]
		var m: int = MAT_INDEX.get(mats[i] if i < mats.size() else "roche", 0)
		for y in range(int(r.position.y / CELL), int(r.end.y / CELL)):
			for x in range(int(r.position.x / CELL), int(r.end.x / CELL)):
				if x >= 0 and y >= 0 and x < gw and y < gh:
					mat[y * gw + x] = (m + 1) * 32
	# Distance de chanfrein en deux passes (le bord de la salle compte comme de la roche).
	var big := MAX_CELLS * 3
	var dist := PackedInt32Array()
	dist.resize(gw * gh)
	for i in gw * gh:
		dist[i] = big if mat[i] > 0 else 0
	for y in gh:
		for x in gw:
			var i := y * gw + x
			if dist[i] == 0:
				continue
			var v := dist[i]
			if x > 0: v = mini(v, dist[i - 1] + 3)
			if y > 0:
				v = mini(v, dist[i - gw] + 3)
				if x > 0: v = mini(v, dist[i - gw - 1] + 4)
				if x < gw - 1: v = mini(v, dist[i - gw + 1] + 4)
			dist[i] = v
	for y in range(gh - 1, -1, -1):
		for x in range(gw - 1, -1, -1):
			var i := y * gw + x
			if dist[i] == 0:
				continue
			var v := dist[i]
			if x < gw - 1: v = mini(v, dist[i + 1] + 3)
			if y < gh - 1:
				v = mini(v, dist[i + gw] + 3)
				if x < gw - 1: v = mini(v, dist[i + gw + 1] + 4)
				if x > 0: v = mini(v, dist[i + gw - 1] + 4)
			dist[i] = v
	var dbytes := PackedByteArray()
	dbytes.resize(gw * gh)
	for i in gw * gh:
		dbytes[i] = clampi(int(dist[i] / 3.0 / MAX_CELLS * 255.0), 0, 255)
	var dimg := Image.create_from_data(gw, gh, false, Image.FORMAT_L8, dbytes)
	var mimg := Image.create_from_data(gw, gh, false, Image.FORMAT_L8, mat)
	return [dimg, mimg]
