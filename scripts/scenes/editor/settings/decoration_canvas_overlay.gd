@tool
extends Control;

func _draw() -> void:
	get_parent().draw_overlay(self);
