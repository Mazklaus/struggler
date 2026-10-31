extends Node
## L'état de la partie, qui survit aux changements de salle : capacités, armes, heure du jour,
## ferraille, ombre de marqué et sauvegarde. Chargé automatiquement sous le nom « World ».

signal night_changed(night: bool)

const SAVE_PATH := "user://struggler_sauvegarde.json"

## Le cycle de la marque : environ 12 minutes, 8 de jour et 4 de nuit.
@export var day_length := 480.0
@export var night_length := 240.0
## Transition douce entre jour et nuit (secondes).
@export var dusk := 12.0

var abilities := {}         # "lourde" (marteau de Gerold), "ruee", "sel"...
var weapons: Array = [0]    # armes forgées (indices Player.W)
var weapon := 0
var clock := 30.0           # secondes depuis l'aube
var cycle_running := false
var scrap := 0              # ferraille
var max_hp := 7
var shadow := {}            # ferraille perdue : {"room", "x", "y", "amount"}
var flags := {}             # objets pris, murs brisés...
var letters: Array = []     # lettres d'Ilse trouvées
var rest_room := ""
var rest_pos := Vector2.ZERO
var current_room := ""

var _was_night := false


func _process(delta: float) -> void:
	if not cycle_running:
		return
	clock = fmod(clock + delta, day_length + night_length)
	_check_night()


func new_game() -> void:
	abilities = {}
	weapons = [0]
	weapon = 0
	clock = 30.0
	scrap = 0
	max_hp = 7
	shadow = {}
	flags = {}
	letters = []
	rest_room = ""
	rest_pos = Vector2.ZERO
	current_room = ""
	_was_night = false
	cycle_running = true


## Salle d'essai : tout est débloqué.
func debug_all() -> void:
	new_game()
	abilities = {"lourde": true, "ruee": true, "sel": true}
	weapons = [0, 1]


func has(ability: String) -> bool:
	return abilities.get(ability, false)


func grant(ability: String) -> void:
	abilities[ability] = true


func is_night() -> bool:
	return clock >= day_length


## 0 en plein jour, 1 en pleine nuit, avec un crépuscule et une aube progressifs.
func night_amount() -> float:
	if clock < day_length:
		return clampf((clock - (day_length - dusk)) / dusk, 0.0, 1.0)
	return clampf((day_length + night_length - clock) / dusk, 0.0, 1.0)


## Secondes avant le prochain changement (tombée de la nuit ou aube).
func time_left() -> float:
	if clock < day_length:
		return day_length - clock
	return day_length + night_length - clock


## Se reposer au sanctuaire jusqu'à la nuit ou jusqu'à l'aube.
func wait_until(night: bool) -> void:
	clock = day_length + 1.0 if night else 1.0
	_check_night()


func _check_night() -> void:
	var n := is_night()
	if n != _was_night:
		_was_night = n
		night_changed.emit(n)


# --- Sauvegarde ----------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version": 1,
		"abilities": abilities, "weapons": weapons, "weapon": weapon,
		"clock": clock, "scrap": scrap, "max_hp": max_hp,
		"shadow": shadow, "flags": flags, "letters": letters,
		"rest_room": rest_room, "rest_x": rest_pos.x, "rest_y": rest_pos.y,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	new_game()
	abilities = data.get("abilities", {})
	weapons = data.get("weapons", [0]).map(func(w): return int(w))
	weapon = int(data.get("weapon", 0))
	clock = float(data.get("clock", 30.0))
	scrap = int(data.get("scrap", 0))
	max_hp = int(data.get("max_hp", 7))
	shadow = data.get("shadow", {})
	flags = data.get("flags", {})
	letters = data.get("letters", []).map(func(l): return int(l))
	rest_room = data.get("rest_room", "")
	rest_pos = Vector2(float(data.get("rest_x", 0.0)), float(data.get("rest_y", 0.0)))
	_was_night = is_night()
	return rest_room != ""
