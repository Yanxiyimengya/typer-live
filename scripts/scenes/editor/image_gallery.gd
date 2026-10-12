extends PanelContainer;

signal import_requested;
signal image_selected(path : String);

var _revision : int = 0;

@onready var tabs : TabBar = %Tabs;
@onready var import_button : Button = %ImportButton;
@onready var delete_button : CheckButton = %DeleteButton;
@onready var import_page : VBoxContainer = %ImportPage;
@onready var gallery_page : VBoxContainer = %GalleryPage;
@onready var image_grid : GridContainer = %ImageGrid;
@onready var empty_label : Label = %EmptyLabel;

func _ready() -> void:
	tabs.tab_changed.connect(_change_tab);
	import_button.pressed.connect(func(): hide(); import_requested.emit());
	delete_button.toggled.connect(_toggle_delete);
	GlobalResourceLoader.history_changed.connect(_history_changed);

func show_gallery() -> void:
	if (visible):
		hide();
		return;
	GlobalResourceLoader.load_history();
	delete_button.set_pressed_no_signal(false);
	size = Vector2(440, 360);
	var button : Control = get_parent();
	var viewport_size : Vector2 = get_viewport_rect().size;
	global_position = Vector2(clampf(button.get_global_rect().position.x, 0, maxf(0, viewport_size.x - size.x)), clampf(button.get_global_rect().end.y + 6, 0, maxf(0, viewport_size.y - size.y)));
	show();
	_change_tab(tabs.current_tab);

func _input(event : InputEvent) -> void:
	if (not visible || not (event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed)):
		return;
	var point : Vector2 = get_canvas_transform().affine_inverse() * event.position;
	if (not get_global_rect().has_point(point) && not get_parent().get_global_rect().has_point(point)):
		hide();

func _change_tab(index : int) -> void:
	import_page.visible = index == 0;
	gallery_page.visible = index == 1;
	delete_button.visible = index == 1;
	if (index == 1 && visible):
		_rebuild_gallery();

func _history_changed() -> void:
	if (visible && tabs.current_tab == 1):
		_rebuild_gallery();

func _toggle_delete(enabled : bool) -> void:
	for button : Button in image_grid.get_children():
		button.disabled = not enabled && not button.get_meta("loaded", false);

func _rebuild_gallery() -> void:
	_revision += 1;
	for child in image_grid.get_children():
		image_grid.remove_child(child);
		child.queue_free();
	empty_label.visible = GlobalResourceLoader.image_history.is_empty();
	for path : String in GlobalResourceLoader.image_history:
		var button : Button = Button.new();
		button.custom_minimum_size = Vector2(94, 94);
		button.text = "加载中…";
		button.tooltip_text = path;
		button.disabled = not delete_button.button_pressed;
		button.pressed.connect(_select_image.bind(path));
		image_grid.add_child(button);
		_load_thumbnail(path, button, _revision);

func _load_thumbnail(path : String, button : Button, revision : int) -> void:
	var texture : ImageTexture = await GlobalResourceLoader.load_image_async(path);
	if (not visible || not is_instance_valid(button) || button.is_queued_for_deletion() || revision != _revision):
		return;
	button.set_meta("loaded", texture != null);
	button.disabled = texture == null && not delete_button.button_pressed;
	button.text = "无法加载" if (texture == null) else "";
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL;
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	if (texture == null):
		return;
	var preview : TextureRect = TextureRect.new();
	preview.texture = texture;
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED;
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	button.add_child(preview);
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);
	preview.offset_left = 5;
	preview.offset_top = 5;
	preview.offset_right = -5;
	preview.offset_bottom = -5;

func _select_image(path : String) -> void:
	if (delete_button.button_pressed):
		GlobalResourceLoader.remove_image(path);
	else:
		hide();
		image_selected.emit(path);
