class_name HexGrid extends Resource

## ── Axial Coordinate System ──
## q = column, r = row. Pointy-top hexes.
## See: https://www.redblobgames.com/grids/hexagons/

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   Vector2i(1, -1),  Vector2i(0, -1),
	Vector2i(-1, 0),  Vector2i(-1, 1),  Vector2i(0, 1),
]

@export var radius: int = 8
var cells: Dictionary = {}

## ── Init ──

func generate_hex_map(r: int = 8) -> void:
	radius = r
	cells.clear()
	for q in range(-radius, radius + 1):
		for r2 in range(-radius, radius + 1):
			var hex = Vector2i(q, r2)
			if abs(q + r2) <= radius:
				cells[hex] = HexCell.new(hex)


## ── Geometry ──

static func hex_to_pixel(hex: Vector2i, hex_size: float = 32.0) -> Vector2:
	var x = hex_size * (sqrt(3) * hex.x + sqrt(3) / 2.0 * hex.y)
	var y = hex_size * (3.0 / 2.0 * hex.y)
	return Vector2(x, y)


static func pixel_to_hex(pos: Vector2, hex_size: float = 32.0) -> Vector2i:
	var q = (sqrt(3) / 3.0 * pos.x - 1.0 / 3.0 * pos.y) / hex_size
	var r = (2.0 / 3.0 * pos.y) / hex_size
	return hex_round(q, r)


static func hex_round(q_f: float, r_f: float) -> Vector2i:
	var s_f = -q_f - r_f
	var q = roundi(q_f)
	var r = roundi(r_f)
	var s = roundi(s_f)
	var qd = abs(q - q_f)
	var rd = abs(r - r_f)
	var sd = abs(s - s_f)
	if qd > rd and qd > sd:
		q = -r - s
	elif rd > sd:
		r = -q - s
	return Vector2i(q, r)


static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), maxi(abs(a.y - b.y), abs((-a.x - a.y) - (-b.x - b.y))))


## ── Navigation (all use step-count, not weighted) ──

func get_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var n: Array[Vector2i] = []
	for d in DIRECTIONS:
		var nb = hex + d
		if cells.has(nb) and cells[nb].is_passable and not cells[nb].occupant:
			n.append(nb)
	return n


func get_range(center: Vector2i, dist: int) -> Array[Vector2i]:
	"""BFS: all passable unoccupied hexes within `dist` steps."""
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [center]
	visited[center] = 0
	while frontier.size() > 0:
		var cur = frontier.pop_front()
		var d = visited[cur]
		if d <= dist and cur != center:
			result.append(cur)
		if d < dist:
			for nb in get_neighbors(cur):
				if not visited.has(nb):
					visited[nb] = d + 1
					frontier.append(nb)
	return result


func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	"""BFS shortest path (unweighted)."""
	if not cells.has(start) or not cells.has(goal):
		return []
	if not cells[goal].is_passable or cells[goal].occupant:
		return []

	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var visited: Dictionary = {}
	visited[start] = true

	while frontier.size() > 0:
		var cur = frontier.pop_front()
		if cur == goal:
			break
		for nb in get_neighbors(cur):
			if nb == goal:
				# Allow goal even if occupied (we're targeting the unit on it)
				came_from[goal] = cur
				frontier.clear()
				break
			if not visited.has(nb):
				visited[nb] = true
				came_from[nb] = cur
				frontier.append(nb)

	if not came_from.has(goal):
		return []

	var path: Array[Vector2i] = []
	var cur2 = goal
	while cur2 != start:
		path.push_front(cur2)
		cur2 = came_from[cur2]
	return path


func get_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var d = distance(from, to)
	if d == 0:
		return result
	for i in range(1, d + 1):
		var t = float(i) / float(d)
		var h = hex_round(lerpf(from.x, to.x, t), lerpf(from.y, to.y, t))
		if h != from and cells.has(h):
			result.append(h)
	return result


## ── Cell ──

class HexCell:
	var coords: Vector2i
	var terrain: int = 0  # TerrainData.Type
	var is_passable: bool = true
	var movement_cost: float = 1.0
	var occupant = null  # Battler
	var is_highlighted: bool = false

	func _init(p: Vector2i):
		coords = p

	func set_terrain(t: int):
		terrain = t
		var td = TerrainData.get_data(t)
		is_passable = td.get("is_passable", true)
		movement_cost = td.get("movement_cost", 1.0)
