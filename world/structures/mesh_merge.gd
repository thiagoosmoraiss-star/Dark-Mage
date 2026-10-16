class_name MeshMerge
extends RefCounted
## Junta as MeshInstance3D descendentes de `root` que usam o mesmo material numa só
## (uma draw call por material). Ignora malhas com script, sombra desligada ou
## sem material_override (props importados, cristais animados).


static func merge(root: Node3D) -> int:
	if not root.is_inside_tree():
		return 0
	var groups: Dictionary = {}  # Material -> Array[MeshInstance3D]
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.material_override == null or mi.get_script() != null or mi.mesh == null or not mi.visible:
			continue
		if mi.get_child_count() > 0 or mi.has_meta(&"no_merge"):
			continue
		var key: Material = mi.material_override
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(mi)
	var removed: int = 0
	var inv: Transform3D = root.global_transform.affine_inverse()
	for mat: Material in groups:
		var list: Array = groups[mat]
		if list.size() < 2:
			continue
		var st: SurfaceTool = SurfaceTool.new()
		for item: Variant in list:
			var mi2: MeshInstance3D = item as MeshInstance3D
			var xf: Transform3D = inv * mi2.global_transform
			for s: int in mi2.mesh.get_surface_count():
				st.append_from(mi2.mesh, s, xf)
		var merged: MeshInstance3D = MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = st.commit()
		merged.material_override = mat
		root.add_child(merged)
		for item2: Variant in list:
			var old: MeshInstance3D = item2 as MeshInstance3D
			old.get_parent().remove_child(old)
			old.queue_free()
			removed += 1
		removed -= 1
	return removed
