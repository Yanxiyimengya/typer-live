extends Node;

signal history_changed;

const SAVE_PATH : String = "user://image_history.cfg";
const MAX_HISTORY : int = 50;
const DECORATION_IMAGES = preload("res://scripts/core/decoration_image_store.gd");

var resource_cache : Dictionary[String, Resource] = {};
var image_history : Array[String] = [];
var _image_jobs : Dictionary[String, Dictionary] = {};

func _ready() -> void:
	load_history();

func load_history() -> void:
	var config : ConfigFile = ConfigFile.new();
	image_history.clear();
	if (config.load(SAVE_PATH) != OK):
		return;
	for path : String in config.get_value("gallery", "images", PackedStringArray()):
		var key : String = _cache_key(path);
		if (not image_history.has(key)):
			image_history.append(key);
		if (image_history.size() == MAX_HISTORY):
			break;

func save_history() -> void:
	var config : ConfigFile = ConfigFile.new();
	config.set_value("gallery", "images", PackedStringArray(image_history));
	config.save(SAVE_PATH);

func remember_image(path : String) -> void:
	var key : String = _cache_key(path);
	image_history.erase(key);
	image_history.push_front(key);
	while image_history.size() > MAX_HISTORY:
		remove_resource(image_history.pop_back());
	save_history();
	history_changed.emit();

func remove_image(path : String) -> void:
	var key : String = _cache_key(path);
	image_history.erase(key);
	remove_resource(key);
	save_history();
	history_changed.emit();

func load_image(path : String) -> ImageTexture:
	var key : String = _cache_key(path);
	if (resource_cache.has(key)):
		return resource_cache[key] as ImageTexture;
	var image : Image = _read_image_file(key);
	if (image == null || image.is_empty()):
		return null;
	var texture : ImageTexture = ImageTexture.create_from_image(image);
	resource_cache[key] = texture;
	return texture;

func load_image_async(path : String) -> ImageTexture:
	var key : String = _cache_key(path);
	if (resource_cache.has(key)):
		return resource_cache[key] as ImageTexture;
	if (not _image_jobs.has(key)):
		var result : Array[Image] = [];
		var task : int = WorkerThreadPool.add_task(
			func():
				result.append(_read_image_file(key));
		);
		_image_jobs[key] = {"task": task, "result": result, "cancelled": false, "finished": false, "texture": null};
	var job : Dictionary = _image_jobs[key];
	while not job.finished && not WorkerThreadPool.is_task_completed(job.task):
		await get_tree().process_frame;
	if (job.finished):
		return null if job.cancelled else job.texture;
	WorkerThreadPool.wait_for_task_completion(job.task);
	job.finished = true;
	if (_image_jobs.has(key) && _image_jobs[key].task == job.task):
		_image_jobs.erase(key);
	if (job.cancelled):
		return null;
	if (resource_cache.has(key)):
		job.texture = resource_cache[key] as ImageTexture;
		return job.texture;
	if (job.result.is_empty()):
		return null;
	var image : Image = job.result[0];
	if (image == null || image.is_empty()):
		return null;
	var texture : ImageTexture = ImageTexture.create_from_image(image);
	resource_cache[key] = texture;
	job.texture = texture;
	return texture;

static func _read_image_file(path : String) -> Image:
	if (not FileAccess.file_exists(path)):
		return null;
	var file : FileAccess = FileAccess.open(path, FileAccess.READ);
	if (file == null):
		return null;
	var length : int = file.get_length();
	var bytes : PackedByteArray = file.get_buffer(length);
	var read_error : Error = file.get_error();
	file.close();
	if (bytes.is_empty() || bytes.size() != length || read_error != OK || not DECORATION_IMAGES.matches_contents(path, bytes)):
		return null;
	# Decode the bytes we checked, so removal during loading cannot cause a second file-open error.
	var image : Image = Image.new();
	var error : Error;
	match path.get_extension().to_lower():
		"png":
			var payload_size : int = _png_payload_size(bytes);
			if (payload_size == 0):
				return null;
			error = image.load_png_from_buffer(bytes.slice(0, payload_size));
		"jpg", "jpeg":
			if (bytes.size() < 4 || bytes.slice(0, 2) != PackedByteArray([255, 216]) || bytes.slice(bytes.size() - 2) != PackedByteArray([255, 217])):
				return null;
			error = image.load_jpg_from_buffer(bytes);
		"webp":
			if (bytes.size() < 12 || bytes.slice(0, 4).get_string_from_ascii() != "RIFF" || bytes.slice(8, 12).get_string_from_ascii() != "WEBP" || bytes.decode_u32(4) + 8 > bytes.size()):
				return null;
			error = image.load_webp_from_buffer(bytes);
		"bmp":
			if (bytes.size() < 26 || bytes.slice(0, 2).get_string_from_ascii() != "BM" || bytes.decode_u32(2) > bytes.size()):
				return null;
			error = image.load_bmp_from_buffer(bytes);
		"svg": error = image.load_svg_from_buffer(bytes);
		_: return null;
	return image if error == OK && not image.is_empty() else null;

static func _png_payload_size(bytes : PackedByteArray) -> int:
	if (bytes.size() < 45 || bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])):
		return 0;
	var offset : int = 8;
	var has_header : bool = false;
	var has_image_data : bool = false;
	while (offset + 12 <= bytes.size()):
		var length : int = (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) | (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3]);
		if (length > bytes.size() - offset - 12):
			return 0;
		var type : String = bytes.slice(offset + 4, offset + 8).get_string_from_ascii();
		if (offset == 8):
			if (type != "IHDR" || length != 13):
				return 0;
			has_header = true;
		if (type == "IDAT"):
			has_image_data = true;
		if (type == "IEND"):
			# Some image exporters append metadata after the complete PNG payload.
			return offset + 12 if length == 0 && has_header && has_image_data else 0;
		offset += length + 12;
	return 0;

func remove_resource(path : String) -> void:
	var key : String = _cache_key(path);
	resource_cache.erase(key);
	if (_image_jobs.has(key)):
		_image_jobs[key].cancelled = true;
		_image_jobs.erase(key);

func clear_cache() -> void:
	resource_cache.clear();
	for job : Dictionary in _image_jobs.values():
		job.cancelled = true;
	_image_jobs.clear();

func _cache_key(path : String) -> String:
	return ProjectSettings.globalize_path(path.replace("\\", "/")).simplify_path();
