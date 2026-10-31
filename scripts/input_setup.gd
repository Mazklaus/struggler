class_name InputSetup
extends RefCounted
## Déclare les commandes en code pour garder project.godot lisible.
## Les touches sont « physiques » : ZQSD sur un clavier AZERTY, WASD sur QWERTY.


static func setup() -> void:
	_action("gauche", [KEY_LEFT], [KEY_A], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("droite", [KEY_RIGHT], [KEY_D], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("haut", [KEY_UP], [KEY_W], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("bas", [KEY_DOWN], [KEY_S], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("saut", [KEY_SPACE], [], [JOY_BUTTON_A], [])
	_action("attaque", [], [KEY_J], [JOY_BUTTON_X], [])
	_action("lourde", [], [KEY_K], [JOY_BUTTON_Y], [])
	_action("ruee", [KEY_SHIFT], [KEY_L], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_action("contre", [], [KEY_I], [JOY_BUTTON_LEFT_SHOULDER], [])
	_action("panser", [], [KEY_F], [JOY_BUTTON_B], [])
	_action("trempe", [], [KEY_E], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_action("glissade", [], [KEY_C], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_action("recommencer", [], [KEY_R], [JOY_BUTTON_BACK], [])
	_action("aide", [], [KEY_H], [JOY_BUTTON_START], [])


static func _action(action: String, keys: Array, physical: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.4)
	for k in keys:
		var e := InputEventKey.new()
		e.keycode = k
		InputMap.action_add_event(action, e)
	for k in physical:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)
