extends Container;

signal decorations_changed;

const ANCHORS : Array[Vector2] = [Vector2.ZERO, Vector2(0.5, 0), Vector2(1, 0), Vector2(0, 0.5), Vector2(0.5, 0.5), Vector2(1, 0.5), Vector2(0, 1), Vector2(0.5, 1), Vector2.ONE];
const DECORATION_IMAGES = preload("res://scripts/core/decoration_image_store.gd");
const APPLE_THEME : Theme = preload("res://assets/styles/editor/apple_editor.tres");
var items : Array = [];
var selected_index : int = -1;
var _loading : bool = false;
@onready var canvas : Control = %DecorationCanvas;

func _ready() -> void:
	add_to_group("decoration_image_editors");
	canvas.preview.set_process(false);
	%ImportDecorationDialog.theme = get_window().theme;
	%DecorationImportError.theme = APPLE_THEME;
	%AnchorOption.get_popup().theme = get_window().theme;
	%AddDecorationButton.pressed.connect(%ImportDecorationDialog.popup_centered.bind(Vector2i(900, 600)));
	%ImportDecorationDialog.file_selected.connect(add_image);
	%RemoveDecorationButton.pressed.connect(_remove_selected);
	%ClearDecorationsButton.pressed.connect(func(): set_data([]); decorations_changed.emit());
	%DecorationNodes.item_selected.connect(_select_node);
	%DecorationNodes.order_requested.connect(_reorder);
	%DecorationNodes.set_column_expand(1, false);
	%DecorationNodes.set_column_custom_minimum_width(1, 44);
	%DecorationNodes.set_column_title(0, "节点");
	%DecorationNodes.set_column_title(1, "层级");
	%DecorationLayer.value_changed.connect(_layer_changed);
	canvas.selection_changed.connect(_select);
	canvas.transform_changed.connect(_transform_changed);
	%MoveTool.pressed.connect(func(): canvas.mode = "move");
	%ScaleTool.pressed.connect(func(): canvas.mode = "scale");
	%RotateTool.pressed.connect(func(): canvas.mode = "rotate");
	%AnchorOption.item_selected.connect(_align);
	%DecorationNameEdit.text_changed.connect(func(value : String): _set_property("name", value));
	%DecorationVisible.toggled.connect(func(value : bool): _set_property("visible", value));
	for control : SpinBox in [%PositionX, %PositionY, %ScaleX, %ScaleY, %DecorationRotation]:
		control.value_changed.connect(_inspector_changed);
	set_data(GlobalSettings.decoration_items);

func _unhandled_key_input(event : InputEvent) -> void:
	if (not is_visible_in_tree() || selected_index < 0 || not event is InputEventKey):
		return;
	if (not event.pressed || event.echo || event.keycode != KEY_DELETE || event.alt_pressed || event.ctrl_pressed || event.meta_pressed || event.shift_pressed):
		return;
	var focus : Control = get_viewport().gui_get_focus_owner();
	if (focus is LineEdit || focus is TextEdit):
		return;
	if (focus != null && focus != self && not is_ancestor_of(focus)):
		return;
	_remove_selected();
	get_viewport().set_input_as_handled();

func set_data(value : Array) -> void:
	items = value.duplicate(true);
	selected_index = -1;
	_rebuild_nodes();
	canvas.select(-1);
	canvas.set_items(items);
	_refresh_inspector();
	GlobalSettings.cleanup_decoration_images();

func _exit_tree() -> void:
	GlobalSettings.call_deferred("cleanup_decoration_images");

func get_data() -> Array:
	return items.duplicate(true);

func set_styles(body : Dictionary, sender : Dictionary) -> void:
	canvas.preview.apply_bubble_styles(body, sender);

func add_image(path : String) -> void:
	var stored_path : String = DECORATION_IMAGES.import_image(path);
	if (stored_path.is_empty()):
		%DecorationImportError.dialog_text = "无法复制图片到本地存储，请检查图片文件及存储目录的访问权限。";
		%DecorationImportError.popup_centered();
		return;
	var texture : Texture2D = GlobalResourceLoader.load_image(stored_path);
	if (texture == null):
		GlobalSettings.cleanup_decoration_images();
		%DecorationImportError.dialog_text = "无法读取图片，文件可能不完整或格式不受支持。\n" + path.get_file();
		%DecorationImportError.popup_centered();
		return;
	var dimensions : Vector2 = texture.get_size();
	dimensions *= minf(1.0, 160.0 / maxf(dimensions.x, dimensions.y));
	items.append({"name": path.get_file().get_basename(), "path": stored_path, "anchor": Vector2(0.5, 0.5), "position": -dimensions / 2.0, "size": dimensions, "scale": Vector2.ONE, "rotation": 0.0, "visible": true});
	_rebuild_nodes();
	_select(items.size() - 1);
	_changed();

func _rebuild_nodes() -> void:
	%DecorationNodes.clear();
	var root : TreeItem = %DecorationNodes.create_item();
	for index in range(items.size() - 1, -1, -1):
		var node : TreeItem = %DecorationNodes.create_item(root);
		node.set_text(0, items[index].name);
		node.set_text(1, str(index + 1));
		node.set_metadata(0, index);
		node.set_selectable(1, false);
		node.set_tooltip_text(0, "拖拽调整层级，越靠上越靠前");

func _select_node() -> void:
	var node : TreeItem = %DecorationNodes.get_selected();
	_select(int(node.get_metadata(0)) if node != null else -1);

func _select(index : int) -> void:
	selected_index = index;
	%DecorationNodes.set_block_signals(true);
	%DecorationNodes.deselect_all();
	if (index >= 0 && index < items.size()):
		var node : TreeItem = %DecorationNodes.get_root().get_child(items.size() - 1 - index);
		node.select(0);
		%DecorationNodes.scroll_to_item(node);
	%DecorationNodes.set_block_signals(false);
	canvas.select(index);
	_refresh_inspector();

func _refresh_inspector() -> void:
	_loading = true;
	%InspectorScroll.visible = selected_index >= 0;
	%RemoveDecorationButton.disabled = selected_index < 0;
	%AnchorOption.disabled = selected_index < 0;
	if (selected_index >= 0):
		var data : Dictionary = items[selected_index];
		%DecorationNameEdit.text = data.name;
		%DecorationVisible.set_pressed_no_signal(data.visible);
		%DecorationLayer.max_value = items.size();
		%DecorationLayer.set_value_no_signal(selected_index + 1);
		%PositionX.set_value_no_signal(data.position.x);
		%PositionY.set_value_no_signal(data.position.y);
		%ScaleX.set_value_no_signal(data.scale.x);
		%ScaleY.set_value_no_signal(data.scale.y);
		%DecorationRotation.set_value_no_signal(data.rotation);
		%AnchorOption.select(ANCHORS.find(data.anchor));
	_loading = false;

func _set_property(key : String, value : Variant) -> void:
	if (_loading || selected_index < 0):
		return;
	items[selected_index][key] = value;
	if (key == "name"):
		%DecorationNodes.get_root().get_child(items.size() - 1 - selected_index).set_text(0, value);
	_changed();

func _layer_changed(value : float) -> void:
	if (_loading || selected_index < 0):
		return;
	_reorder(selected_index, int(value) - 1);

func _reorder(from_index : int, to_index : int) -> void:
	if (from_index < 0 || from_index >= items.size() || to_index < 0 || to_index >= items.size() || from_index == to_index):
		return;
	var item : Dictionary = items[from_index];
	items.remove_at(from_index);
	items.insert(to_index, item);
	# Keep the same object selected when other nodes move past it.
	if (selected_index == from_index):
		selected_index = to_index;
	elif (from_index < selected_index && to_index >= selected_index):
		selected_index -= 1;
	elif (from_index > selected_index && to_index <= selected_index):
		selected_index += 1;
	_rebuild_nodes();
	_select(selected_index);
	_changed();

func _inspector_changed(_value : float) -> void:
	if (_loading || selected_index < 0):
		return;
	items[selected_index].position = Vector2(%PositionX.value, %PositionY.value);
	items[selected_index].scale = Vector2(%ScaleX.value, %ScaleY.value);
	items[selected_index].rotation = %DecorationRotation.value;
	_changed();

func _transform_changed(index : int, data : Dictionary) -> void:
	if (%SnapToGrid.button_pressed && data.position != items[index].position):
		data.position = data.position.snapped(Vector2(10, 10));
	items[index] = data;
	_refresh_inspector();
	_changed();

func _align(index : int) -> void:
	if (selected_index < 0):
		return;
	items[selected_index].anchor = ANCHORS[index];
	items[selected_index].position = -items[selected_index].size / 2.0;
	_refresh_inspector();
	_changed();

func _remove_selected() -> void:
	if (selected_index < 0):
		return;
	items.remove_at(selected_index);
	_rebuild_nodes();
	_select(mini(selected_index, items.size() - 1));
	_changed();
	GlobalSettings.cleanup_decoration_images();

func _changed() -> void:
	canvas.set_items(items);
	decorations_changed.emit();
