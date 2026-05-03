class_name TerrainData extends Resource

enum Type {
	GRASS,
	FOREST,
	MOUNTAIN,
	SWAMP,
	WATER,
	LAVA,
	SAND,
	RUINS,
	MAGIC_CIRCLE,
}

## Terrain properties
static func get_data(type: Type) -> Dictionary:
	match type:
		Type.GRASS:
			return {
				"name": "Grass",
				"is_passable": true,
				"movement_cost": 1.0,
				"evasion_bonus": 0.0,
				"defense_bonus": 0,
				"elemental_boost": Element.Type.NONE,
				"elemental_multiplier": 1.0,
			}
		Type.FOREST:
			return {
				"name": "Forest",
				"is_passable": true,
				"movement_cost": 1.5,
				"evasion_bonus": 0.20,    # +20% dodge
				"defense_bonus": 5,
				"elemental_boost": Element.Type.WIND,
				"elemental_multiplier": 1.2,
			}
		Type.MOUNTAIN:
			return {
				"name": "Mountain",
				"is_passable": false,  # can't move through
				"movement_cost": 0.0,
				"evasion_bonus": 0.0,
				"defense_bonus": 10,   # +10 DEF when on it (reachable hexes that are mountains)
				"elemental_boost": Element.Type.EARTH,
				"elemental_multiplier": 1.3,
			}
		Type.SWAMP:
			return {
				"name": "Swamp",
				"is_passable": true,
				"movement_cost": 2.0,   # slow
				"evasion_bonus": -0.10, # easier to hit
				"defense_bonus": 0,
				"elemental_boost": Element.Type.WATER,
				"elemental_multiplier": 1.1,
			}
		Type.WATER:
			return {
				"name": "Water",
				"is_passable": false,  # water hexes block movement (flying units could bypass)
				"movement_cost": 0.0,
				"evasion_bonus": 0.0,
				"defense_bonus": 0,
				"elemental_boost": Element.Type.WATER,
				"elemental_multiplier": 1.5,
			}
		Type.LAVA:
			return {
				"name": "Lava",
				"is_passable": true,
				"movement_cost": 2.0,
				"evasion_bonus": 0.0,
				"defense_bonus": 0,
				"elemental_boost": Element.Type.FIRE,
				"elemental_multiplier": 1.5,
			}
		Type.SAND:
			return {
				"name": "Sand",
				"is_passable": true,
				"movement_cost": 1.5,
				"evasion_bonus": 0.0,
				"defense_bonus": 0,
				"elemental_boost": Element.Type.EARTH,
				"elemental_multiplier": 1.1,
			}
		Type.RUINS:
			return {
				"name": "Ruins",
				"is_passable": true,
				"movement_cost": 1.0,
				"evasion_bonus": 0.0,
				"defense_bonus": 5,
				"elemental_boost": Element.Type.DARK,
				"elemental_multiplier": 1.2,
			}
		Type.MAGIC_CIRCLE:
			return {
				"name": "Magic Circle",
				"is_passable": true,
				"movement_cost": 1.0,
				"evasion_bonus": 0.0,
				"defense_bonus": 0,
				"elemental_boost": Element.Type.LIGHT,
				"elemental_multiplier": 1.3,
			}

	return {}

static func get_name(type: Type) -> String:
	return get_data(type).get("name", "Unknown")
