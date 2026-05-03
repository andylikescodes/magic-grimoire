class_name Element

enum Type {
	NONE = 0,
	FIRE = 1,
	WATER = 2,
	WIND = 3,
	EARTH = 4,
	LIGHT = 5,
	DARK = 6,
}

## Returns 1.5 for super effective, 1.0 for neutral, 0.5 for not very effective
static func get_multiplier(attack: Type, target: Type) -> float:
	# Fire > Wind > Earth > Water > Fire
	# Light <> Dark (both super effective against each other)
	match attack:
		Type.FIRE:
			if target == Type.WIND:   return 1.5
			if target == Type.WATER:  return 0.5
		Type.WIND:
			if target == Type.EARTH:  return 1.5
			if target == Type.FIRE:   return 0.5
		Type.EARTH:
			if target == Type.WATER:  return 1.5
			if target == Type.WIND:   return 0.5
		Type.WATER:
			if target == Type.FIRE:   return 1.5
			if target == Type.EARTH:  return 0.5
		Type.LIGHT:
			if target == Type.DARK:   return 1.5
		Type.DARK:
			if target == Type.LIGHT:  return 1.5

	return 1.0

static func get_name(type: Type) -> String:
	return Type.keys()[type]

static func get_color(type: Type) -> Color:
	match type:
		Type.FIRE:  return Color.RED
		Type.WATER: return Color.DODGER_BLUE
		Type.WIND:  return Color.LAWN_GREEN
		Type.EARTH: return Color.SADDLE_BROWN
		Type.LIGHT: return Color.GOLD
		Type.DARK:  return Color.PURPLE
	return Color.WHITE
