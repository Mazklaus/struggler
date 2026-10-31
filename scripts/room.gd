class_name Room
extends Node2D
## Une salle construite à partir de son dessin en caractères (voir Rooms).
## Elle porte ses blocs, son décor, ses ennemis et ses objets ; on la jette en sortant.

const TILE := 32.0

var id := ""
var data := {}
var size := Vector2.ZERO
var solids: Array[Rect2] = []
var water: Array[Rect2] = []
var hazards: Array[Rect2] = []
var rests: Array = []            # [{"rect": Rect2, "kind": "S" ou "F"}]
var doors := {}                  # chiffre -> Rect2
var spirit_points: Array[Vector2] = []
var start_pos := Vector2.ZERO    # case P, s'il y en a une
var deco: LevelDraw

var _night_shapes: Array[CollisionShape2D] = []


func build(room_id: String) -> void:
	id = room_id
	data = Rooms.DATA[room_id]
	var rows: Array = data.rows
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	size = Vector2(w * TILE, rows.size() * TILE)

	deco = LevelDraw.new()
	add_child(deco)

	var body := StaticBody2D.new()
	add_child(body)
	var mist := StaticBody2D.new()
	add_child(mist)
	var mist_rects: Array[Rect2] = []
	var plank_rects: Array[Rect2] = []
	var corpses: Array[Vector2] = []
	var wells: Array[Rect2] = []

	for y in rows.size():
		var line: String = rows[y]
		var x := 0
		while x < line.length():
			var ch := line[x]
			if ch in ["#", "^", "w", "=", "-"]:
				var start := x
				while x < line.length() and line[x] == ch:
					x += 1
				var rect := Rect2(start * TILE, y * TILE, (x - start) * TILE, TILE)
				match ch:
					"=":
						mist_rects.append(rect)
					"-":
						plank_rects.append(rect)
					"w":
						wells.append(rect)
						_merge_down(rect)
					_:
						_merge_down(rect)
				if ch == "^":
					hazards.append(Rect2(rect.position + Vector2(4, -6), Vector2(rect.size.x - 8, 14)))
				continue
			var cell := Vector2(x * TILE, y * TILE)
			var feet := cell + Vector2(TILE * 0.5, TILE)
			match ch:
				"~":
					water.append(Rect2(cell, Vector2(TILE, TILE)))
				"S", "F":
					rests.append({"rect": Rect2(cell + Vector2(-TILE * 0.5, 0), Vector2(TILE * 2.0, TILE)), "kind": ch})
				"P":
					start_pos = feet + Vector2(0, -28)
				"G":
					spirit_points.append(cell + Vector2(TILE * 0.5, TILE * 0.5))
				"g":
					var s := Spirit.new()
					s.position = cell + Vector2(TILE * 0.5, TILE * 0.5)
					s.daylight = true
					add_child(s)
				"c":
					corpses.append(feet)
				"E":
					var e := Soldier.new()
					e.position = feet + Vector2(0, -29)
					add_child(e)
				"D":
					var d := Dummy.new()
					d.position = feet + Vector2(0, -32)
					add_child(d)
				"B":
					var boss_id: String = data.get("boss", "")
					if boss_id == "contremaitre" and not World.flags.has("boss:" + boss_id):
						var b := Contremaitre.new()
						b.position = feet + Vector2(0, -Contremaitre.BODY.y * 0.5)
						add_child(b)
				"R":
					var r := Rampant.new()
					r.position = feet + Vector2(0, -12)
					add_child(r)
				_:
					if ch.is_valid_int():
						var dr: Rect2 = Rect2(cell, Vector2(TILE, TILE))
						doors[ch] = doors[ch].merge(dr) if doors.has(ch) else dr
					elif Rooms.ITEMS.has(ch):
						var key := "%s:%s:%d,%d" % [id, ch, x, y]
						if not World.flags.has(key):
							var it := Pickup.new()
							it.item = Rooms.ITEMS[ch]
							it.flag = key
							it.position = cell + Vector2(TILE * 0.5, TILE * 0.5)
							add_child(it)
			x += 1

	for rect in solids:
		_add_box(body, rect)
	for rect in mist_rects:
		var shape := _add_box(mist, rect)
		shape.one_way_collision = true
		_night_shapes.append(shape)
	for rect in plank_rects:
		_add_box(mist, rect).one_way_collision = true

	# Murs fissurés : un bloc par groupe de X ; un mur brisé le reste.
	var done := {}
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if line[x] != "X" or done.has(Vector2i(x, y)):
				continue
			var wx := 0
			while x + wx < line.length() and line[x + wx] == "X":
				wx += 1
			var h := 0
			while y + h < rows.size() and x < rows[y + h].length() and rows[y + h][x] == "X":
				h += 1
			for j in h:
				for i in wx:
					done[Vector2i(x + i, y + j)] = true
			var key := "%s:X:%d,%d" % [id, x, y]
			if World.flags.has(key):
				continue
			var wall := FragileWall.new()
			wall.rect = Rect2(x * TILE, y * TILE, wx * TILE, h * TILE)
			wall.flag = key
			add_child(wall)

	deco.water = water
	deco.hazards = hazards
	deco.rests = rests
	deco.solids = solids
	deco.mist = mist_rects
	deco.planks = plank_rects
	deco.corpses = corpses
	deco.wells = wells
	for hnt in data.get("hints", []):
		deco.hints.append([Vector2(hnt[0] * TILE, hnt[1] * TILE), hnt[2]])
	set_night(World.is_night())


## La brume se fige la nuit : ses plateformes n'existent qu'à ce moment-là.
func set_night(night: bool) -> void:
	for s in _night_shapes:
		s.set_deferred("disabled", not night)


func rest_at(rect: Rect2) -> Dictionary:
	for r in rests:
		if rect.intersects(r.rect):
			return r
	return {}


## Le joueur est-il à l'abri dans un cercle de sel ?
func in_salt(pos: Vector2) -> bool:
	for r in rests:
		if r.kind == "S" and r.rect.grow_individual(16, 64, 16, 8).has_point(pos):
			return true
	return false


## Position d'arrivée par un passage : juste à l'intérieur de la salle.
func door_arrival(digit: String) -> Vector2:
	if not doors.has(digit):
		return start_pos
	var r: Rect2 = doors[digit]
	var feet_y := r.end.y - 28.0
	if r.position.x <= 0.0:
		return Vector2(r.end.x + 30.0, feet_y)
	if r.end.x >= size.x:
		return Vector2(r.position.x - 30.0, feet_y)
	if r.position.y <= 0.0:
		return Vector2(r.get_center().x, r.end.y + 40.0)
	return Vector2(r.get_center().x, r.position.y - 40.0)


func floor_below(pos: Vector2) -> float:
	var best := size.y
	for r in solids:
		if pos.x >= r.position.x and pos.x <= r.end.x and r.position.y >= pos.y - 4.0:
			best = minf(best, r.position.y)
	return best


func _merge_down(rect: Rect2) -> void:
	for i in solids.size():
		var r := solids[i]
		if r.position.x == rect.position.x and r.size.x == rect.size.x and r.end.y == rect.position.y:
			solids[i] = r.merge(rect)
			return
	solids.append(rect)


func _add_box(body: StaticBody2D, rect: Rect2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	return shape
