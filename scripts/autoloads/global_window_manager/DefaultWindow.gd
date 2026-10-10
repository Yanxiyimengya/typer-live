class_name DefaultWindow;
extends Window;

var _id : int = 0;
var close_request : bool = true;

func _ready() -> void:
	close_requested.connect(_on_close_requested);

func _on_close_requested() -> void : 
	if (close_request) : 
		GlobalWindowManager.delete_window(_id);
