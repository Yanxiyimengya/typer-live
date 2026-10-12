extends RefCounted;

static func plain_text(text : String) -> String:
	var result : String = "";
	var index : int = 0;
	while (index < text.length()):
		if (text[index] != "["):
			result += text[index];
			index += 1;
			continue;
		var end : int = index + 1;
		var quoted : bool = false;
		var escaped : bool = false;
		while (end < text.length()):
			var character : String = text[end];
			if (escaped):
				escaped = false;
			elif (quoted && character == "\\"):
				escaped = true;
			elif (character == '"'):
				quoted = not quoted;
			elif (character == "]" && not quoted):
				break;
			end += 1;
		if (end == text.length()):
			result += text.substr(index);
			break;
		var tag : String = text.substr(index + 1, end - index - 1).strip_edges();
		var command : String = tag.get_slice(" ", 0).get_slice("=", 0).to_lower();
		if (command == "img"):
			var closing : int = text.find("[/img]", end + 1);
			if (closing != -1):
				index = closing + 6;
				continue;
		match command:
			"lb": result += "[";
			"rb": result += "]";
			"br", "hr", "p", "/p": result += "\n";
		index = end + 1;
	return result.strip_edges();
