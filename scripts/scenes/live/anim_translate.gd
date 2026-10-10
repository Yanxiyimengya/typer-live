@tool
extends Control;

@export var alpha : float = 1.0 : 
	set(value) : 
		modulate.a = value;
		alpha = value;

func _ready() -> void:
	pass;
