extends Container;

signal decorations_changed;

const ANCHORS : Array[Vector2] = [Vector2.ZERO, Vector2(0.5, 0), Vector2(1, 0), Vector2(0, 0.5), Vector2(0.5, 0.5), Vector2(1, 0.5), Vector2(0, 1), Vector2(0.5, 1), Vector2.ONE];
const DECORATION_IMAGES = preload("res://scripts/core/decoration_image_store.gd");
const APPLE_THEME : Theme = preload("res://assets/styles/editor/apple_editor.tres");
var items : Array = [];
var selected_index : int = -1;
var _loading : bool = false;
@onready var canvas : Control = %DecorationCanvas;

@onready var import_decoration_dialog : FileDialog = %ImportDecorationDialog;
@onready var decoration_import_error : AcceptDialog = %DecorationImportError;
@onready var anchor_option : OptionButton = %AnchorOption;
@onready var add_decoration_button : Button = %AddDecorationButton;
@onready var remove_decoration_button : Button = %RemoveDecorationButton;
@onready var clear_decorations_button : Button = %ClearDecorationsButton;
@onready var decoration_nodes : Tree = %DecorationNodes;
@onready var decoration_layer : SpinBox = %DecorationLayer;
@onready var move_tool : Button = %MoveTool;
@onready var scale_tool : Button = %ScaleTool;
@onready var rotate_tool : Button = %RotateTool;
@onready var decoration_name_edit : LineEdit = %DecorationNameEdit;
@onready var decoration_visible : CheckBox = %DecorationVisible;
@onready var position_x : SpinBox = %PositionX;
@onready var position_y : SpinBox = %PositionY;
@onready var scale_x : SpinBox = %ScaleX;
@onready var scale_y : SpinBox = %ScaleY;
@onready var decoration_rotation : SpinBox = %DecorationRotation;
@onready var inspector_scroll : ScrollContainer = %InspectorScroll;
@onready var snap_to_grid : CheckButton = %SnapToGrid;

func _ready() -> void:
	add_to_group("decoration_image_editors");
	canvas.preview.set_process(false);
	import_decoration_dialog.theme = get_window().theme;
	decoration_import_error.theme = APPLE_THEME;
	anchor_option.get_popup().theme = get_window().theme;
	add_decoration_button.pressed.connect(import_decoration_dialog.popup_centered.bind(Vector2i(900, 600)));
	import_decoration_dialog.file_selected.connect(add_image);
	remove_decoration_button.pressed.connect(_remove_selected);
	clear_decorations_button.pressed.connect(func(): set_data([]); decorations_changed.emit());
	decoration_nodes.item_selected.connect(_select_node);
	decoration_nodes.order_requested.connect(_reorder);
	decoration_nodes.set_column_expand(1, false);
	decoration_nodes.set_column_custom_minimum_width(1, 44);
	decoration_nodes.set_column_title(0, "节点");
	decoration_nodes.set_column_title(1, "层级");
	decoration_layer.value_changed.connect(_layer_changed);
	canvas.selection_changed.connect(_select);
	canvas.transform_changed.connect(_transform_changed);
	move_tool.pressed.connect(func(): canvas.mode = "move");
	scale_tool.pressed.connect(func(): canvas.mode = "scale");
	rotate_tool.pressed.connect(func(): canvas.mode = "rotate");
	anchor_option.item_selected.connect(_align);
	decoration_name_edit.text_changed.connect(func(value : String): _set_property("name", value));
	decoration_visible.toggled.connect(func(value : bool): _set_property("visible", value));
	for control : SpinBox in [position_x, position_y, scale_x, scale_y, decoration_rotation]:
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
		decoration_import_error.dialog_text = "无法复制图片到本地存储，请检查图片文件及存储目录的访问权限。";
		decoration_import_error.popup_centered();
		return;
	var texture : Texture2D = GlobalResourceLoader.load_image(stored_path);
	if (texture == null):
		GlobalSettings.cleanup_decoration_images();
		decoration_import_error.dialog_text = "无法读取图片，文件可能不完整或格式不受支持。\n" + path.get_file();
		decoration_import_error.popup_centered();
		return;
	var dimensions : Vector2 = texture.get_size();
	dimensions *= minf(1.0, 160.0 / maxf(dimensions.x, dimensions.y));
	items.append({"name": path.get_file().get_basename(), "path": stored_path, "anchor": Vector2(0.5, 0.5), "position": -dimensions / 2.0, "size": dimensions, "scale": Vector2.ONE, "rotation": 0.0, "visible": true});
	_rebuild_nodes();
	_select(items.size() - 1);
	_changed();

func _rebuild_nodes() -> void:
	decoration_nodes.clear();
	var root : TreeItem = decoration_nodes.create_item();
	for index in range(items.size() - 1, -1, -1):
		var node : TreeItem = decoration_nodes.create_item(root);
		node.set_text(0, items[index].name);
		node.set_text(1, str(index + 1));
		node.set_metadata(0, index);
		node.set_selectable(1, false);
		node.set_tooltip_text(0, "拖拽调整层级，越靠上越靠前");

func _select_node() -> void:
	var node : TreeItem = decoration_nodes.get_selected();
	_select(int(node.get_metadata(0)) if node != null else -1);

func _select(index : int) -> void:
	selected_index = index;
	decoration_nodes.set_block_signals(true);
	decoration_nodes.deselect_all();
	if (index >= 0 && index < items.size()):
		var node : TreeItem = decoration_nodes.get_root().get_child(items.size() - 1 - index);
		node.select(0);
		decoration_nodes.scroll_to_item(node);
	decoration_nodes.set_block_signals(false);
	canvas.select(index);
	_refresh_inspector();

func _refresh_inspector() -> void:
	_loading = true;
	inspector_scroll.visible = selected_index >= 0;
	remove_decoration_button.disabled = selected_index < 0;
	anchor_option.disabled = selected_index < 0;
	if (selected_index >= 0):
		var data : Dictionary = items[selected_index];
		decoration_name_edit.text = data.name;
		decoration_visible.set_pressed_no_signal(data.visible);
		decoration_layer.max_value = items.size();
		decoration_layer.set_value_no_signal(selected_index + 1);
		position_x.set_value_no_signal(data.position.x);
		position_y.set_value_no_signal(data.position.y);
		scale_x.set_value_no_signal(data.scale.x);
		scale_y.set_value_no_signal(data.scale.y);
		decoration_rotation.set_value_no_signal(data.rotation);
		anchor_option.select(ANCHORS.find(data.anchor));
	_loading = false;

func _set_property(key : String, value : Variant) -> void:
	if (_loading || selected_index < 0):
		return;
	items[selected_index][key] = value;
	if (key == "name"):
		decoration_nodes.get_root().get_child(items.size() - 1 - selected_index).set_text(0, value);
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
	items[selected_index].position = Vector2(position_x.value, position_y.value);
	items[selected_index].scale = Vector2(scale_x.value, scale_y.value);
	items[selected_index].rotation = decoration_rotation.value;
	_changed();

func _transform_changed(index : int, data : Dictionary) -> void:
	if (snap_to_grid.button_pressed && data.position != items[index].position):
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
