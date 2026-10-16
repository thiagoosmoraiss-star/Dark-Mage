extends Node
## Inventário em grade (36 casas) e equipamento (cajado, manto, amuleto). Só dados;
## a UI lê e altera por estes métodos. Materiais ficam no GameState.

signal changed

const SIZE: int = 36
const START_ITEMS: Array[Array] = [["potion_health", 3], ["potion_mana", 2]]

## Cada casa: {} (vazia) ou {"id": String, "count": int}.
var slots: Array[Dictionary] = []
var equipped: Dictionary[String, String] = {"staff": "staff_apprentice", "robe": "", "amulet": ""}


func _ready() -> void:
	add_to_group(&"inventory")
	reset()


func reset() -> void:
	slots.clear()
	for i: int in SIZE:
		slots.append({})
	equipped = {"staff": "staff_apprentice", "robe": "", "amulet": ""}
	for e: Array in START_ITEMS:
		add(str(e[0]), roundi(JsonUtil.num(e[1])))
	changed.emit()


func id_at(i: int) -> String:
	return JsonUtil.get_s(slots[i], "id") if i >= 0 and i < SIZE else ""


func count_at(i: int) -> int:
	return JsonUtil.get_i(slots[i], "count") if i >= 0 and i < SIZE else 0


func count(id: String) -> int:
	var n: int = 0
	for s: Dictionary in slots:
		if JsonUtil.get_s(s, "id") == id:
			n += JsonUtil.get_i(s, "count")
	return n


func owns(id: String) -> bool:
	return count(id) > 0 or equipped.values().has(id)


func free_slots() -> int:
	var n: int = 0
	for s: Dictionary in slots:
		if s.is_empty():
			n += 1
	return n


## Adiciona `n` unidades; devolve quantas couberam.
func add(id: String, n: int = 1) -> int:
	if not ItemDb.exists(id) or n <= 0:
		return 0
	var left: int = n
	if ItemDb.stackable(id):
		for s: Dictionary in slots:
			if left > 0 and JsonUtil.get_s(s, "id") == id:
				var c: int = JsonUtil.get_i(s, "count")
				var put: int = mini(ItemDb.STACK_MAX - c, left)
				s["count"] = c + put
				left -= put
	for i: int in SIZE:
		if left <= 0:
			break
		if slots[i].is_empty():
			var put2: int = mini(ItemDb.STACK_MAX if ItemDb.stackable(id) else 1, left)
			slots[i] = {"id": id, "count": put2}
			left -= put2
	if left != n:
		changed.emit()
	return n - left


func remove_at(i: int, n: int = 1) -> void:
	if i < 0 or i >= SIZE or slots[i].is_empty():
		return
	var c: int = JsonUtil.get_i(slots[i], "count") - n
	slots[i] = {} if c <= 0 else {"id": id_at(i), "count": c}
	changed.emit()


func remove(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	var left: int = n
	for i: int in range(SIZE - 1, -1, -1):
		if left > 0 and id_at(i) == id:
			var take: int = mini(count_at(i), left)
			remove_at(i, take)
			left -= take
	return true


## Arrastar e soltar: troca duas casas (ou junta pilhas iguais).
func move(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= SIZE or to >= SIZE:
		return
	var a: Dictionary = slots[from]
	var b: Dictionary = slots[to]
	if not a.is_empty() and not b.is_empty() and a["id"] == b["id"] and ItemDb.stackable(str(a["id"])):
		var total: int = JsonUtil.get_i(a, "count") + JsonUtil.get_i(b, "count")
		slots[to] = {"id": a["id"], "count": mini(total, ItemDb.STACK_MAX)}
		slots[from] = {} if total <= ItemDb.STACK_MAX else {"id": a["id"], "count": total - ItemDb.STACK_MAX}
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()


## Equipa o item da casa `i`; o que estava equipado volta para a mesma casa.
func equip_from(i: int) -> bool:
	var id: String = id_at(i)
	if not ItemDb.is_equipment(id):
		return false
	var slot: String = ItemDb.slot_name(id)
	var old: String = equipped[slot] if equipped.has(slot) else ""
	equipped[slot] = id
	slots[i] = {} if old == "" else {"id": old, "count": 1}
	changed.emit()
	return true


func unequip(slot: String) -> bool:
	var id: String = equipped[slot] if equipped.has(slot) else ""
	if id == "" or slot == "staff" or free_slots() == 0:
		return false  # sempre há um cajado equipado
	equipped[slot] = ""
	add(id, 1)
	changed.emit()
	return true


## Usa um consumível da casa `i` no jogador.
func use_at(i: int, player: Player) -> bool:
	var id: String = id_at(i)
	var u: Dictionary = ItemDb.get_item(id).get("use", {})
	if u.is_empty() or player == null:
		return false
	var st: PlayerStats = player.stats
	if u.has("health"):
		st.heal(st.max_health * JsonUtil.num(u["health"]))
	if u.has("mana"):
		st.set_mana(minf(st.mana + st.max_mana * JsonUtil.num(u["mana"]), st.max_mana))
	if u.has("stamina"):
		st.set_stamina(st.max_stamina)
	remove_at(i, 1)
	Audio.play(&"ui_confirm")
	return true


## Usa a primeira poção de `id` (atalho rápido da HUD).
func quick_use(id: String, player: Player) -> bool:
	for i: int in SIZE:
		if id_at(i) == id:
			return use_at(i, player)
	return false


func bonus(stat: String) -> float:
	var total: float = 0.0
	for id: String in equipped.values():
		if id != "":
			total += ItemDb.bonus(id, stat)
	return total


## Parâmetros do ataque básico do cajado equipado.
func basic_attack() -> Dictionary:
	var staff: String = equipped["staff"] if equipped.has("staff") else "staff_apprentice"
	var b: Dictionary = ItemDb.get_item(staff).get("basic", {})
	return b if not b.is_empty() else ItemDb.get_item("staff_apprentice")["basic"]


func to_dict() -> Dictionary:
	var grid: Array = []
	for s: Dictionary in slots:
		grid.append(s.duplicate())
	return {"slots": grid, "equipped": equipped.duplicate()}


## Carrega validando: ids desconhecidos e contagens absurdas são descartados.
func from_dict(d: Dictionary) -> void:
	slots.clear()
	for i: int in SIZE:
		slots.append({})
	var grid: Variant = d.get("slots", [])
	if grid is Array:
		var arr: Array = grid
		for i: int in mini(arr.size(), SIZE):
			if arr[i] is Dictionary:
				var e: Dictionary = arr[i]
				var id: String = JsonUtil.get_s(e, "id")
				var c: int = clampi(JsonUtil.get_i(e, "count"), 0, ItemDb.STACK_MAX)
				if ItemDb.exists(id) and c > 0:
					slots[i] = {"id": id, "count": c if ItemDb.stackable(id) else 1}
	equipped = {"staff": "staff_apprentice", "robe": "", "amulet": ""}
	var eq: Variant = d.get("equipped", {})
	if eq is Dictionary:
		for slot: String in ItemDb.EQUIP_SLOTS:
			var id2: String = JsonUtil.get_s(eq as Dictionary, slot)
			if ItemDb.exists(id2) and ItemDb.slot_name(id2) == slot:
				equipped[slot] = id2
	changed.emit()
