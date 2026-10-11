extends RefCounted;

const DIRECTORY : String = "user://decoration_images";
const EXTENSIONS : PackedStringArray = ["png", "jpg", "jpeg", "webp", "bmp", "svg"];

static func is_managed(path : String) -> bool:
	var normalized : String = path.replace("\\", "/").simplify_path();
	if (normalized.get_base_dir() != DIRECTORY):
		return false;
	var name : String = normalized.get_file().get_basename();
	if (name.length() != 64 || normalized.get_extension() not in EXTENSIONS):
		return false;
	for character in name:
		if (character not in "0123456789abcdef"):
			return false;
	return true;

static func import_image(path : String) -> String:
	if (is_managed(path)):
		return path if FileAccess.file_exists(path) && FileAccess.get_sha256(path) == path.get_file().get_basename() else "";
	var extension : String = path.get_extension().to_lower();
	if (extension not in EXTENSIONS):
		return "";
	var source : FileAccess = FileAccess.open(path, FileAccess.READ);
	if (source == null):
		return "";
	var length : int = source.get_length();
	var bytes : PackedByteArray = source.get_buffer(length);
	source.close();
	if (bytes.is_empty() || bytes.size() != length):
		return "";
	var digest : String = hash_bytes(bytes);
	if (digest.is_empty()):
		return "";
	if (DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK):
		return "";
	# Reuse identical bytes even if their source filenames/extensions differ.
	var destination : String = "";
	for existing_extension in EXTENSIONS:
		var existing : String = DIRECTORY.path_join(digest + "." + existing_extension);
		if (FileAccess.file_exists(existing)):
			if (FileAccess.get_sha256(existing) == digest):
				return existing;
			# Repair a damaged copy at the same path to preserve existing references.
			destination = existing;
			break;
	if (extension == "jpeg"):
		extension = "jpg";
	if (destination.is_empty()):
		destination = DIRECTORY.path_join(digest + "." + extension);
	var temporary : String = destination + ".tmp";
	var output : FileAccess = FileAccess.open(temporary, FileAccess.WRITE);
	if (output == null):
		return "";
	output.store_buffer(bytes);
	output.flush();
	var error : Error = output.get_error();
	output.close();
	if (error == OK):
		error = DirAccess.rename_absolute(temporary, destination);
	if (error != OK):
		DirAccess.remove_absolute(temporary);
		return "";
	return destination;

static func hash_bytes(bytes : PackedByteArray) -> String:
	var hash : HashingContext = HashingContext.new();
	if (hash.start(HashingContext.HASH_SHA256) != OK || hash.update(bytes) != OK):
		return "";
	return hash.finish().hex_encode();

static func matches_contents(path : String, bytes : PackedByteArray) -> bool:
	var local_path : String = path.replace("\\", "/").simplify_path();
	var absolute_directory : String = ProjectSettings.globalize_path(DIRECTORY).replace("\\", "/").simplify_path();
	if (local_path.get_base_dir() == absolute_directory):
		local_path = DIRECTORY.path_join(local_path.get_file());
	return not is_managed(local_path) || hash_bytes(bytes) == local_path.get_file().get_basename();

static func collect_unused(references : Array) -> void:
	if (not DirAccess.dir_exists_absolute(DIRECTORY)):
		return;
	var retained : Dictionary = {};
	for item : Dictionary in references:
		retained[str(item.get("path", "")).replace("\\", "/").simplify_path()] = true;
	for filename in DirAccess.get_files_at(DIRECTORY):
		var path : String = DIRECTORY.path_join(filename);
		if (is_managed(path) && not retained.has(path)):
			if (DirAccess.remove_absolute(path) == OK):
				GlobalResourceLoader.remove_resource(path);
