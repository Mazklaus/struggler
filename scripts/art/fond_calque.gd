class_name FondCalque
extends Node2D
## Le fond d'une ambiance dans une salle : une grande image en parallaxe (« fond ») ou des modules
## répétés (« fond_modules »), plus sa brume (« voile », couleur « brume » de la palette).
## L'ambiance du dehors couvre toute la salle ; une ambiance d'intérieur se pose par-dessus,
## découpée par son masque (voir RoomArt._build_fonds), avec un contour d'encre à son bord.
## « flou » : flou de profondeur (niveau de mipmap), pour les plans lointains.

var room: Room
var conf := {}
var dir := ""
var _bg: Sprite2D
var _mods: Node2D
var _haze: ColorRect
var _mask: Texture2D
var _shader: Shader
var _interieur := false
var _couches: Array = []   # [Node2D, parallaxe, repère (Vector2, monde de la salle)]
var _verifie := false


func setup(r: Room, zone_dir: String, amb: Dictionary, mask: Texture2D, interieur := false) -> void:
	room = r
	dir = zone_dir
	conf = amb
	_mask = mask
	_interieur = interieur
	var zb := -26 if interieur else -30
	_shader = load("res://art/shaders/fond_ambiance.gdshader")
	if amb.has("fond") and not amb.has("couches"):
		_bg = Sprite2D.new()
		_bg.texture = load(dir + amb.fond)
		_bg.centered = false
		_bg.region_enabled = true
		_bg.z_index = zb
		_bg.material = _mat()
		add_child(_bg)
	if amb.has("fond_modules"):
		_build_modules(amb.fond_modules)
	if amb.has("couches"):
		_build_couches(amb.couches, zb)
	var pal: Dictionary = amb.get("palette", {})
	_haze = ColorRect.new()
	_haze.size = room.size
	_haze.color = Color(pal.get("brume", "000000"))
	# Avec des couches, chacune a son propre voile : la brume d'ensemble s'efface.
	_haze.color.a = 0.0 if amb.has("couches") else amb.get("voile", 0.3)
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze.z_index = zb + 1
	var hm := _mat()
	hm.set_shader_parameter("unie", true)
	_haze.material = hm
	add_child(_haze)


func _mat(fondu := 0.0, fondu_x := 0.0, vertical := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("fondu", fondu)
	m.set_shader_parameter("fondu_x", fondu_x)
	m.set_shader_parameter("vertical", vertical)
	m.set_shader_parameter("use_mask", _mask != null)
	m.set_shader_parameter("interieur", _interieur)
	m.set_shader_parameter("flou", float(conf.get("flou", 0.0)))
	var pal: Dictionary = conf.get("palette", {})
	m.set_shader_parameter("c_encre", Color(pal.get("encre", "1d1420")))
	m.set_shader_parameter("c_lumiere", Color(pal.get("lumiere", "f2a866")))
	if _mask:
		m.set_shader_parameter("mask", _mask)
		m.set_shader_parameter("room_rect", Vector4(room.global_position.x, room.global_position.y, room.size.x, room.size.y))
	return m


## Décor par couches (voir la remise à plat du rendu) : du ciel au plan juste derrière le jeu,
## chaque couche défile à sa parallaxe. Une couche est soit une bande « image » répétée en
## largeur, soit des « elements » placés. Tout se règle à l'écran, en mètres apparents au plan du
## jeu : « sol » = ligne de sol de la couche (en cases de la salle, vue depuis le « repere »),
## « hauteur » = hauteur affichée. Sous son sol, chaque couche finit en brume (« brume », en
## mètres, puis plein) : on ne voit jamais le bas d'un bâtiment. « voile » : part de la couleur
## de l'air mêlée à la couche (plus c'est loin, plus c'est fort).
func _build_couches(list: Array, zb: int) -> void:
	var T := float(Room.TILE)
	var pal: Dictionary = conf.get("palette", {})
	var air := Color(pal.get("brume", "8a5560"))
	var ombre := Color(pal.get("ombre", "3a2a44"))
	for cdef in list:
		var d: Dictionary = cdef
		var f := float(d.get("parallaxe", 0.2))
		var rep: Array = d.get("repere", [room.size.x / T * 0.5, room.size.y / T * 0.5])
		var node := Node2D.new()
		node.z_index = zb
		add_child(node)
		_couches.append([node, f, Vector2(float(rep[0]), float(rep[1])) * T, d])
		var voile := float(d.get("voile", 0.0))
		var sol := float(d.get("sol", room.size.y / T)) * T
		var mat := _mat()
		mat.set_shader_parameter("flou", float(d.get("flou", 0.0)))
		# « teinte » : couleur vers laquelle tirer la couche (par défaut l'air) ; « ombre » pour
		# assombrir un plan proche en silhouette.
		var tc := air
		if d.get("teinte", "") == "ombre":
			tc = ombre
		elif d.has("teinte"):
			tc = Color(str(d.teinte))
		mat.set_shader_parameter("voile_c", tc)
		mat.set_shader_parameter("voile_k", voile)
		if d.has("image"):
			var tex: Texture2D = load(dir + str(d.image))
			var hpx := float(d.get("hauteur", 10.0)) * T
			var k := hpx / tex.get_height()
			var wpx := tex.get_width() * k
			var x := -1400.0
			var i := 0
			while x < room.size.x + 1400.0:
				var sp := Sprite2D.new()
				sp.texture = tex
				sp.centered = false
				sp.scale = Vector2(k, k)
				# une fois sur deux en miroir : la répétition se voit moins
				sp.flip_h = i % 2 == 1 and bool(d.get("miroir", true))
				sp.position = Vector2(x, sol + float(d.get("enfonce", 0.0)) * T - hpx)
				sp.material = mat
				node.add_child(sp)
				x += wpx - 1.0
				i += 1
		for e in d.get("elements", []):
			var tex: Texture2D = load(dir + str(e.image))
			var hpx := float(e.get("hauteur", 8.0)) * T
			var k := hpx / tex.get_height()
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.scale = Vector2(k, k)
			sp.flip_h = bool(e.get("miroir", false))
			var ex := float(e.get("x", 0.0)) * T
			sp.position = Vector2(ex - tex.get_width() * k * 0.5, sol + float(e.get("enfonce", 0.5)) * T - hpx)
			sp.material = mat
			node.add_child(sp)
		var bh := float(d.get("brume", 0.0)) * T
		if d.has("brume"):
			# Brume au pied : dégradé de la couleur de la couche lointaine vers le plein, puis plein.
			var c := air.lerp(ombre, clampf(1.0 - voile, 0.0, 1.0) * 0.6)
			var g := Gradient.new()
			g.set_color(0, Color(c, 0.0))
			g.set_color(1, Color(c, 1.0))
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.fill_from = Vector2(0, 0)
			gt.fill_to = Vector2(0, 1)
			gt.width = 4
			gt.height = 64
			var band := Sprite2D.new()
			band.texture = gt
			band.centered = false
			band.scale = Vector2((room.size.x + 2800.0) / 4.0, maxf(bh, 1.0) / 64.0)
			band.position = Vector2(-1400.0, sol - bh)
			band.material = _mat()
			node.add_child(band)
			var fill := ColorRect.new()
			fill.color = c
			fill.position = Vector2(-1400.0, sol - 1.0)
			fill.size = Vector2(room.size.x + 2800.0, room.size.y + 1600.0)
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var fm := _mat()
			fm.set_shader_parameter("unie", true)
			fill.material = fm
			node.add_child(fill)


## Règle des bases : le sol de chaque couche doit rester sous celui de la couche suivante (plus
## proche), quelle que soit la hauteur de la caméra dans la salle. Avertit sinon, avec la marge.
func _verifier_bases(view: Vector2) -> void:
	_verifie = true
	var T := float(Room.TILE)
	var cmin := view.y * 0.5
	var cmax := maxf(room.size.y - view.y * 0.5, cmin)
	for i in range(_couches.size() - 1):
		var a: Array = _couches[i]
		var b: Array = _couches[i + 1]
		var da: Dictionary = a[3]
		var db: Dictionary = b[3]
		if not da.has("brume") or not db.has("brume"):
			continue
		var sa := float(da.get("sol", 0.0)) * T
		var sb := float(db.get("sol", 0.0)) * T
		for cy in [cmin, cmax]:
			# hauteur à l'écran d'un sol s, couche de parallaxe f, repère r : s + (cy - r)(1 - f) - cy
			var ya: float = sa + (cy - a[2].y) * (1.0 - float(a[1]))
			var yb: float = sb + (cy - b[2].y) * (1.0 - float(b[1]))
			if ya < yb - 2.0:
				push_warning("%s : le sol de la couche %d se voit au-dessus de la couche %d (%.1f m) quand la caméra est à y=%.0f" % [room.id, i, i + 1, (yb - ya) / T, cy])


## Fond fait de modules : un morceau de décor à la bonne échelle, qui se raccorde à lui-même
## dans l'axe de la salle (vertical pour un puits, horizontal pour une galerie). La taille d'un
## module est fixée en pixels du monde : c'est elle qui règle l'échelle du fond par rapport à
## Wendel, quelle que soit la taille de la salle. Grille de colonnes décalées entre variantes.
func _build_modules(m: Dictionary) -> void:
	_mods = Node2D.new()
	_mods.z_index = -26 if _interieur else -30
	add_child(_mods)
	var vertical: bool = m.get("axe", "vertical") == "vertical"
	var base: Array = m.get("base", [])
	if base.is_empty():
		return
	var texs: Array[Texture2D] = []
	for b in base:
		texs.append(load(dir + b))
	var f: float = conf.get("parallaxe", 0.15)
	# Largeur couverte en travers (hauteur si horizontal) : le fond défile aussi dans cet axe, à la
	# même fraction f que dans l'autre ; il doit donc couvrir la salle entière vue à travers f.
	var cross := maxf(float(m.get("largeur", 1280.0)),
			(room.size.x if vertical else room.size.y) * f + (1280.0 if vertical else 720.0) * 1.5)
	# taille d'un module en travers. « taille_m » : ce que le module mesure en vrai, en mètres ;
	# vu derrière le plan du jeu, il paraît réduit dans le rapport de la parallaxe (plus loin =
	# défile moins vite = paraît plus petit). Sinon « taille » en pixels du monde (ancien réglage).
	var side: float = m.get("taille", cross)
	if m.has("taille_m"):
		side = float(m.taille_m) * Room.TILE * f
	var length := (room.size.y if vertical else room.size.x) * f + (720.0 if vertical else 1280.0) * 1.5
	var fondu: float = m.get("fondu", 0.15) if texs.size() > 1 else 0.0
	var cols := int(ceil(cross / (side * (1.0 - fondu)))) if m.has("taille") or m.has("taille_m") else 1
	for c in cols:
		var pos := -side * 2.0 * fmod(c * 0.37, 1.0) if c > 0 else 0.0
		var i := c * 2 + 1 if c > 0 else 0
		var first_row := true
		while pos < length:
			var t: Texture2D = texs[(i * 7 + (i / texs.size()) * 3) % texs.size()]
			i += 1
			var sp := Sprite2D.new()
			sp.texture = t
			sp.centered = false
			var k := side / (t.get_width() if vertical else t.get_height())
			sp.scale = Vector2(k, k)
			var step := t.get_height() * k if vertical else t.get_width() * k
			var cross_pos := c * side * (1.0 - fondu)
			if not first_row:
				pos -= step * fondu
			sp.material = _mat(0.0 if first_row else fondu, 0.0 if c == 0 else fondu, vertical)
			sp.position = Vector2(cross_pos, pos) if vertical else Vector2(pos, cross_pos)
			_mods.add_child(sp)
			pos += step
			first_row = false


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view := get_viewport_rect().size / cam.zoom
	var tl := cam.get_screen_center_position() - view * 0.5 - room.global_position
	var f: float = conf.get("parallaxe", 0.15)
	var night := World.night_amount()
	var tint := Color(1, 1, 1).lerp(Color(0.55, 0.6, 0.8), night)
	if not _couches.is_empty():
		if not _verifie:
			_verifier_bases(view)
		var c := tl + view * 0.5
		for e in _couches:
			# La couche est à sa place quand la caméra est sur le repère ; elle suit la caméra
			# à la fraction (1 - f) de son déplacement depuis ce repère.
			(e[0] as Node2D).position = (c - (e[2] as Vector2)) * (1.0 - float(e[1]))
			(e[0] as Node2D).modulate = tint
	if _mods:
		# Les modules défilent à la fraction f de la caméra, dans les deux axes (avant, ils étaient
		# collés à la caméra en travers : en sautant, le fond d'une maison montait avec Wendel).
		_mods.position = tl * (1.0 - f)
		_mods.modulate = tint
	if _bg:
		# Le fond couvre la vue et défile au moins d'une fraction f du déplacement de la caméra.
		# S'il est plus grand que nécessaire, il défile juste assez pour qu'on en voie les bords.
		var travel := (room.size - view).max(Vector2.ZERO)
		var need := view + travel * f
		var tex := _bg.texture.get_size()
		var k := maxf(need.y / tex.y, need.x / tex.x)
		var shown := tex * k
		var fx := clampf((shown.x - view.x) / travel.x, 0.0, 1.0) if travel.x > 0.0 else 0.0
		var fy := clampf((shown.y - view.y) / travel.y, 0.0, 1.0) if travel.y > 0.0 else 0.0
		_bg.scale = Vector2(k, k)
		_bg.region_rect = Rect2(Vector2.ZERO, tex)
		_bg.position = tl - Vector2(tl.x * fx, tl.y * fy)
		_bg.modulate = tint
