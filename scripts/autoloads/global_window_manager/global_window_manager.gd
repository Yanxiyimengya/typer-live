extends Node;

var _window_list : Dictionary[int, DefaultWindow] = {};
var _window_id_counter : int = 1;

func _enter_tree() -> void:
	_init_windows();

func _exit_tree() -> void:
	_uninit_windows();

func _init_windows() -> void :
	_window_list.clear();

func _uninit_windows() -> void :
	for id : int in _window_list : 
		var w : Window = _window_list.get(id, null);
		if (w) : 
			w.queue_free();
	_window_list.clear();

## 申请一个新的窗口
func new_window() -> int : 
	var id : int = _window_id_counter;
	var window : DefaultWindow = DefaultWindow.new();
	window._id = id;
	_window_list[id] = window;
	_window_id_counter += 1;
	self.call_deferred("add_child", window);
	return id;

## 寻找窗口对象
func find_window(window_id : int) -> Window : 
	return _window_list.get(window_id, null) as Window;

func delete_window(window_id : int) -> void : 
	if (_window_list.has(window_id)) : 
		var window : DefaultWindow = _window_list[window_id];
		window.queue_free();
		_window_list.erase(window_id);
