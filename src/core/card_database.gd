class_name CardDatabase extends Node

## ── Central Card Database ──
## Loads and manages all card definitions from JSON/Resources

var all_cards: Dictionary = {}  # card_id -> CardData

func _ready():
	load_card_database()


func load_card_database() -> void:
	"""Load all card data from JSON files in assets/cards/"""
	var dir_path = "res://assets/cards/"
	var dir = DirAccess.open(dir_path)
	if not dir:
		push_warning("Card database directory not found: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".json"):
			_load_card(dir_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("CardDatabase: Loaded %d cards" % all_cards.size())


func _load_card(path: String) -> void:
	var card: CardData
	if path.ends_with(".tres"):
		card = load(path) as CardData
	elif path.ends_with(".json"):
		card = _parse_card_json(path)

	if card and card.card_id != "":
		all_cards[card.card_id] = card


func _parse_card_json(path: String) -> CardData:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		return null

	var data = json.get_data()
	var card = CardData.new()
	card.card_id = data.get("card_id", "")
	card.display_name = data.get("display_name", "")
	card.element = data.get("element", Element.Type.NONE)
	card.rarity = data.get("rarity", CardData.Rarity.COMMON)
	card.base_hp = data.get("base_hp", 100)
	card.base_atk = data.get("base_atk", 50)
	card.base_def = data.get("base_def", 30)
	card.base_spd = data.get("base_spd", 40)
	card.movement_range = data.get("movement_range", 3)
	card.sprite_path = data.get("sprite_path", "")
	card.portrait_path = data.get("portrait_path", "")
	return card


func get_card(card_id: String) -> CardData:
	if all_cards.has(card_id):
		return all_cards[card_id]
	return null


func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in all_cards:
		ids.append(id)
	return ids


func get_cards_by_element(element: Element.Type) -> Array[CardData]:
	var result: Array[CardData] = []
	for card in all_cards.values():
		if card.element == element:
			result.append(card)
	return result
