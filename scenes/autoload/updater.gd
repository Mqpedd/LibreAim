extends Node
## Checks GitHub for a newer macOS build and installs it on request.
## Only active in macOS builds made by the release workflow, which writes
## res://build_info.cfg with the commit the build came from.

signal update_available

const RELEASE_URL := "https://github.com/Mqpedd/LibreAim/releases/download/latest/"
const BUILD_INFO_PATH := "res://build_info.cfg"
const SCRIPT_SOURCE := "res://tools/update_macos.sh"

var is_update_available := false
var _build_id := ""

func _ready() -> void:
	if not _can_self_update():
		return
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_check_completed.bind(request))
	request.request(RELEASE_URL + "build_id.txt")

## App bundle path, or "" when not running from an exported .app
func get_app_path() -> String:
	var executable := OS.get_executable_path()
	if not executable.contains(".app/Contents/MacOS/"):
		return ""
	return executable.get_base_dir().get_base_dir().get_base_dir()

## macOS runs apps from a read-only copy until they are moved out of Downloads
func is_translocated() -> bool:
	return get_app_path().contains("/AppTranslocation/")

func apply_update() -> void:
	var script := FileAccess.get_file_as_string(SCRIPT_SOURCE)
	var script_path := ProjectSettings.globalize_path("user://update_macos.sh")
	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null or script.is_empty():
		push_warning("Could not write update script")
		return
	file.store_string(script)
	file.close()
	OS.create_process("/bin/bash", [script_path, get_app_path(), \
		str(OS.get_process_id()), RELEASE_URL + "LibreAim-macOS.zip"])
	get_tree().quit()

func _can_self_update() -> bool:
	if OS.get_name() != "macOS" or get_app_path().is_empty():
		return false
	var config := ConfigFile.new()
	if config.load(BUILD_INFO_PATH) != OK:
		return false
	_build_id = config.get_value("build", "id", "")
	return not _build_id.is_empty()

func _on_check_completed(result: int, code: int, _headers: PackedStringArray, \
		body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var latest := body.get_string_from_utf8().strip_edges()
	if latest.is_empty() or latest == _build_id:
		return
	is_update_available = true
	update_available.emit()
