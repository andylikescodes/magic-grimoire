class_name MoveData extends Resource

@export var move_id: String = ""
@export var display_name: String = ""
@export var element: Element.Type = Element.Type.NONE

## Move type
enum Category { PHYSICAL, MAGICAL, SUPPORT }
@export var category: Category = Category.PHYSICAL

@export var base_power: int = 60
@export var accuracy: int = 100  # 0-100, 100 = always hits
@export var mp_cost: int = 10    # MP / stamina cost
@export var cooldown: int = 0    # turns before can use again

## Range
@export var min_range: int = 1   # min hex distance
@export var max_range: int = 1   # max hex distance
@export var is_aoe: bool = false # affects area around target

## Special effects
@export var status_effect: String = ""  # "burn", "freeze", "poison", etc.
@export var status_chance: float = 0.0   # 0.0 - 1.0
@export var heal_amount: int = 0         # for healing moves
@export var buff_atk: int = 0            # self/ally buff
@export var buff_def: int = 0
@export var buff_spd: int = 0

## Visual
@export var animation_name: String = ""

func get_description() -> String:
	var parts: Array[String] = []

	match category:
		Category.SUPPORT:
			if heal_amount > 0:
				parts.append("Restore %d HP" % heal_amount)
			if buff_atk != 0:
				parts.append("ATK %+d" % buff_atk)
			if buff_def != 0:
				parts.append("DEF %+d" % buff_def)
		_:
			parts.append("Power: %d | Acc: %d%%" % [base_power, accuracy])

	if status_effect != "":
		parts.append("[%s %d%%]" % [status_effect, int(status_chance * 100)])

	if mp_cost > 0:
		parts.append("Cost: %d MP" % mp_cost)

	return " | ".join(parts)
