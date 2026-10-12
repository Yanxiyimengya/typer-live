@tool
extends Control;

signal selection_changed(index : int);
signal transform_changed(index : int, data : Dictionary);

const SCENE_SIZE : Vector2 = Vector2(800, 300);
var items : Array = [];
var selected_index : int = -1;
var mode : String = "move";
var zoom : float = 1.0;
var _display_scale : float = 1.0;
var _origin : Vector2;
var _pan : Vector2;
var _drag : String = "";
var _drag_from_handle : bool = false;
var _drag_corner : int = -1;
var _start_mouse : Vector2;
var _start_data : Dictionary;
var _center : Vector2;

@onready var preview : Control = %DialogBubble;

@onready var viewport_container : SubViewportContainer = %ViewportContainer;
@onready var overlay : Control = %Overlay;

func _ready() -> void:
	resized.connect(_layout_canvas);
	_layout_canvas();

func _layout_canvas() -> void:
	_display_scale = maxf(0.1, minf((size.x - 64.0) / SCENE_SIZE.x, (size.y - 64.0) / SCENE_SIZE.y)) * zoom;
	_origin = (size - SCENE_SIZE * _display_scale) / 2.0 + _pan + Vector2(12, 12);
	viewport_container.position = _origin;
	viewport_container.scale = Vector2.ONE * _display_scale;
	queue_redraw();
	if (is_instance_valid(overlay)):
		overlay.queue_redraw();

func set_items(value : Array) -> void:
	items = value.duplicate(true);
	preview.apply_item_decorations(items);
	queue_redraw();
	if (is_instance_valid(overlay)):
		overlay.queue_redraw();

func select(index : int) -> void:
	selected_index = index;
	queue_redraw();
	if (is_instance_valid(overlay)):
		overlay.queue_redraw();

func _item() -> Control:
	return preview.decoration_items_layer.get_child(selected_index);

func _corners() -> PackedVector2Array:
	var item : Control = _item();
	var transform : Transform2D = item.get_global_transform();
	var result : PackedVector2Array = [];
	for corner : Vector2 in [Vector2.ZERO, Vector2(item.size.x, 0), item.size, Vector2(0, item.size.y)]:
		result.append(_origin + (transform * corner) * _display_scale);
	return result;

func _rotation_handle(corners : PackedVector2Array) -> Vector2:
	return (corners[0] + corners[1]) / 2.0 + ((corners[0] + corners[1] - corners[2] - corners[3]) / 2.0).normalized() * 26.0;

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.18, 0.21));
	var step : float = 20.0 * _display_scale;
	for axis in range(2):
		var extent : float = size.x if axis == 0 else size.y;
		var origin : float = _origin.x if axis == 0 else _origin.y;
		for grid_index in range(int(floor(-origin / step)), int(ceil((extent - origin) / step)) + 1):
			var coordinate : float = origin + grid_index * step;
			var color : Color = Color(0.28, 0.31, 0.35, 0.65) if grid_index % 5 == 0 else Color(0.23, 0.26, 0.30, 0.6);
			if (axis == 0):
				draw_line(Vector2(coordinate, 24), Vector2(coordinate, size.y), color);
			else:
				draw_line(Vector2(24, coordinate), Vector2(size.x, coordinate), color);
	draw_rect(Rect2(_origin, SCENE_SIZE * _display_scale), Color(0.53, 0.59, 0.67), false);

func draw_overlay(overlay : Control) -> void:
	var step : float = 20.0 * _display_scale;
	if (selected_index >= 0 && selected_index < items.size() && is_instance_valid(preview)):
		var corners : PackedVector2Array = _corners();
		var outline : PackedVector2Array = corners.duplicate();
		outline.append(corners[0]);
		overlay.draw_polyline(outline, Color(0.32, 0.77, 1), 2, true);
		for corner in corners:
			overlay.draw_rect(Rect2(corner - Vector2(4, 4), Vector2(8, 8)), Color.WHITE);
		var handle : Vector2 = _rotation_handle(corners);
		overlay.draw_line((corners[0] + corners[1]) / 2.0, handle, Color(0.32, 0.77, 1), 2);
		overlay.draw_circle(handle, 5, Color(0.32, 0.77, 1));
		
	overlay.draw_rect(Rect2(0, 0, size.x, 24), Color(0.22, 0.25, 0.29));
	overlay.draw_rect(Rect2(0, 0, 24, size.y), Color(0.22, 0.25, 0.29));
	var font : Font = ThemeDB.fallback_font;
	for axis in range(2):
		var extent : float = size.x if axis == 0 else size.y;
		var origin : float = _origin.x if axis == 0 else _origin.y;
		for tick in range(int(floor(-origin / step)), int(ceil((extent - origin) / step)) + 1):
			var coordinate : float = origin + tick * step;
			if (coordinate < 24):
				continue;
			var major : bool = tick % 5 == 0;
			if (axis == 0):
				overlay.draw_line(Vector2(coordinate, 24), Vector2(coordinate, 14 if major else 20), Color(0.66, 0.71, 0.77));
				if (major): overlay.draw_string(font, Vector2(coordinate + 3, 12), str(tick * 20), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.84, 0.89));
			else:
				overlay.draw_line(Vector2(24, coordinate), Vector2(14 if major else 20, coordinate), Color(0.66, 0.71, 0.77));
				if (major): overlay.draw_string(font, Vector2(1, coordinate - 3), str(tick * 20), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.84, 0.89));

func _update_cursor(mouse_position : Vector2) -> void:
	if (_drag == "move" || _drag == "pan"):
		mouse_default_cursor_shape = Control.CURSOR_MOVE;
		return;
	if (_drag == "rotate"):
		mouse_default_cursor_shape = Control.CURSOR_CROSS;
		return;
	var corners : PackedVector2Array = PackedVector2Array();
	var center : Vector2 = Vector2.ZERO;
	if (selected_index >= 0 && selected_index < items.size() && is_instance_valid(preview)):
		corners = _corners();
		center = (corners[0] + corners[1] + corners[2] + corners[3]) / 4.0;
	if (_drag == "scale"):
		if (_drag_corner >= 0 && _drag_corner < corners.size()):
			var rel : Vector2 = corners[_drag_corner] - center;
			mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if (rel.x * rel.y >= 0.0) else Control.CURSOR_BDIAGSIZE;
		else:
			mouse_default_cursor_shape = Control.CURSOR_HSIZE;
		return;
	if (corners.size() > 0):
		if (mouse_position.distance_to(_rotation_handle(corners)) < 12):
			mouse_default_cursor_shape = Control.CURSOR_CROSS;
			return;
		for index in range(corners.size()):
			if (mouse_position.distance_to(corners[index]) < 12):
				var rel : Vector2 = corners[index] - center;
				mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if (rel.x * rel.y >= 0.0) else Control.CURSOR_BDIAGSIZE;
				return;
	mouse_default_cursor_shape = Control.CURSOR_ARROW;

func _gui_input(event : InputEvent) -> void:
	if (event is InputEventMouseButton):
		if (event.pressed && event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
			zoom = clampf(zoom * (1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1), 0.35, 3.0);
			_layout_canvas();
			accept_event();
		elif (event.button_index == MOUSE_BUTTON_MIDDLE):
			_drag = "pan" if event.pressed else "";
			_update_cursor(event.position);
			accept_event();
		elif (event.button_index == MOUSE_BUTTON_LEFT):
			if (not event.pressed):
				_drag = "";
				_update_cursor(event.position);
				return;
			grab_focus();
			var handle_mode : String = "";
			_drag_corner = -1;
			if (selected_index >= 0 && selected_index < items.size()):
				var corners : PackedVector2Array = _corners();
				if (event.position.distance_to(_rotation_handle(corners)) < 12):
					handle_mode = "rotate";
				for corner_index in range(corners.size()):
					if (event.position.distance_to(corners[corner_index]) < 12):
						handle_mode = "scale";
						_drag_corner = corner_index;
			if (handle_mode.is_empty()):
				var picked : int = -1;
				var scene_point : Vector2 = (event.position - _origin) / _display_scale;
				for index in range(items.size() - 1, -1, -1):
					var item : Control = preview.decoration_items_layer.get_child(index);
					if (item.visible && Rect2(Vector2.ZERO, item.size).has_point(item.get_global_transform().affine_inverse() * scene_point)):
						picked = index;
						break;
				select(picked);
				selection_changed.emit(picked);
			if (selected_index >= 0):
				_drag = mode if handle_mode.is_empty() else handle_mode;
				_drag_from_handle = not handle_mode.is_empty();
				_start_mouse = event.position;
				_start_data = items[selected_index].duplicate(true);
				_center = _origin + (_item().get_global_transform() * (_item().size / 2.0)) * _display_scale;
			_update_cursor(event.position);
			accept_event();
	elif (event is InputEventMouseMotion):
		_update_cursor(event.position);
		if (_drag.is_empty()):
			return;
		if (_drag == "pan"):
			_pan += event.relative;
			_layout_canvas();
		elif (selected_index >= 0):
			var data : Dictionary = _start_data.duplicate(true);
			match _drag:
				"move": data.position += (event.position - _start_mouse) / _display_scale;
				"scale":
					var ratio : float = event.position.distance_to(_center) / maxf(1, _start_mouse.distance_to(_center)) if _drag_from_handle else exp((event.position.x - _start_mouse.x) / 120.0);
					data.scale = (data.scale * ratio).clamp(Vector2(0.05, 0.05), Vector2(20, 20));
				"rotate":
					var angle_delta : float = rad_to_deg((event.position - _center).angle() - (_start_mouse - _center).angle()) if _drag_from_handle else (event.position.x - _start_mouse.x) * 0.5;
					data.rotation = _start_data.rotation + angle_delta;
					if (event.shift_pressed):
						data.rotation = snappedf(data.rotation, 15.0);
			transform_changed.emit(selected_index, data);
			accept_event();
