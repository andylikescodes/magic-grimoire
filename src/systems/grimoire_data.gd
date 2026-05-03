class_name GrimoireData extends Resource

## ── The Grimoire ──
## The summoner's personal spellbook / card collection

@export var owner_name: String = ""
@export var collection: Array[CardData] = []  # all collected cards
@export var decks: Array[DeckData] = []        # saved deck configurations

## ── Filters ──

func filter_by_element(element: Element.Type) -> Array[CardData]:
	var result: Array[CardData] = []
	for card in collection:
		if card.element == element:
			result.append(card)
	return result


func filter_by_rarity(rarity: CardData.Rarity) -> Array[CardData]:
	var result: Array[CardData] = []
	for card in collection:
		if card.rarity == rarity:
			result.append(card)
	return result


func search_by_name(query: String) -> Array[CardData]:
	var result: Array[CardData] = []
	var lowered = query.to_lower()
	for card in collection:
		if lowered in card.display_name.to_lower():
			result.append(card)
	return result


func get_cards_in_deck(deck_index: int) -> Array[CardData]:
	if deck_index < 0 or deck_index >= decks.size():
		return []
	return decks[deck_index].cards


## ── Collection Management ──

func add_card(card: CardData) -> void:
	# Check for duplicate
	for existing in collection:
		if existing.card_id == card.card_id:
			# Could add "duplicate count" or level up
			return
	collection.append(card)


func remove_card(card_id: String) -> bool:
	for i in range(collection.size()):
		if collection[i].card_id == card_id:
			collection.remove_at(i)
			return true
	return false


func get_collection_count() -> int:
	return collection.size()


## ── Serialization ──

func to_dict() -> Dictionary:
	var result = {
		"owner_name": owner_name,
		"card_ids": [],
		"decks": [],
	}
	for card in collection:
		result["card_ids"].append(card.card_id)
	for deck in decks:
		result["decks"].append(deck.to_dict())
	return result


func from_dict(data: Dictionary, card_lookup: Callable) -> void:
	owner_name = data.get("owner_name", "")
	collection.clear()
	for card_id in data.get("card_ids", []):
		var card = card_lookup.call(card_id)
		if card:
			collection.append(card)
	# Decks loaded separately
