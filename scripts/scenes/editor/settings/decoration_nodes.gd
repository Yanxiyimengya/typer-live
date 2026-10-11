extends Tree;

signal order_requested(from_index : int, to_index : int);

func _get_drag_data(at_position : Vector2) -> Variant:
	var item : TreeItem = get_item_at_position(at_position);
	if (item == null):
		return null;
	var label : Label = Label.new();
	label.text = item.get_text(0);
	set_drag_preview(label);
	return {"tree": self, "index": int(item.get_metadata(0))};

func _can_drop_data(at_position : Vector2, data : Variant) -> bool:
	drop_mode_flags = Tree.DROP_MODE_DISABLED;
	if (not data is Dictionary || data.get("tree") != self):
		return false;
	drop_mode_flags = Tree.DROP_MODE_INBETWEEN;
	var target : TreeItem = get_item_at_position(at_position);
	if (target == null || get_drop_section_at_position(at_position) not in [-1, 1]):
		drop_mode_flags = Tree.DROP_MODE_DISABLED;
		return false;
	return true;

func _drop_data(at_position : Vector2, data : Variant) -> void:
	if (not _can_drop_data(at_position, data)):
		return;
	var target : TreeItem = get_item_at_position(at_position);
	var from_index : int = int(data.index);
	# The tree displays front to back, opposite to the drawing order.
	var insertion_index : int = int(target.get_metadata(0));
	if (get_drop_section_at_position(at_position) == -1):
		insertion_index += 1;
	if (from_index < insertion_index):
		insertion_index -= 1;
	drop_mode_flags = Tree.DROP_MODE_DISABLED;
	order_requested.emit(from_index, insertion_index);
