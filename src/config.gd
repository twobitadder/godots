extends Node


signal saved


var AUTO_EDSCALE = 1
var EDSCALE = 1
var AGENT = ""
const VERSION = "v1.1.dev"
const APP_CONFIG_PATH = "user://godots.cfg"
const EDITORS_CONFIG_PATH = "user://editors.cfg"
const PROJECTS_CONFIG_PATH = "user://projects.cfg"
const DEFAULT_VERSIONS_PATH = "user://versions"
const DEFAULT_DOWNLOADS_PATH = "user://downloads"
const RELEASES_URL = "https://github.com/MakovWait/godots/releases"
const RELEASES_LATEST_API_ENDPOINT = "https://api.github.com/repos/MakovWait/godots/releases/latest"

const _EDITOR_PROXY_SECTION_NAME = "theme"

var _cfg = ConfigFile.new()
var _cfg_auto_save = ConfigFileSaveOnSet.new(
	_cfg, 
	APP_CONFIG_PATH, 
	func(err):
		if err == OK:
			saved.emit() 
		pass\
)


var AGENT_HEADER:
	get: return "User-Agent: %s" % AGENT


var VERSIONS_PATH = ConfigFileValue.new(
	_cfg_auto_save, 
	"app", 
	"versions_path",
	DEFAULT_VERSIONS_PATH
).map_return_value(_simplify_path): 
	set(_v): _readonly()


var DOWNLOADS_PATH = ConfigFileValue.new(
	_cfg_auto_save, 
	"app", 
	"downloads_path",
	DEFAULT_DOWNLOADS_PATH
).map_return_value(_simplify_path): 
	set(_v): _readonly()


var SAVED_EDSCALE = ConfigFileValue.new(
	_cfg_auto_save, 
	_EDITOR_PROXY_SECTION_NAME, 
	"interface/editor/custom_display_scale"
): 
	set(_v): _readonly()


var DEFAULT_EDITOR_TAGS = ConfigFileValue.new(
	_cfg_auto_save, 
	"app", 
	"default_editor_tags",
	["dev", "rc", "alpha", "4.x", "3.x", "stable", "mono"]
): 
	set(_v): _readonly()


var DEFAULT_PROJECT_TAGS = ConfigFileValue.new(
	_cfg_auto_save, 
	"app", 
	"default_project_tags",
	[]
): 
	set(_v): _readonly()


var AUTO_CLOSE = ConfigFileValue.new(
	_cfg_auto_save, 
	"app", 
	"auto_close",
	false
): 
	set(_v): _readonly()


var SHOW_ORPHAN_EDITOR = ConfigFileValue.new(
	_cfg_auto_save, 
	"app", 
	"show_orphan_editor",
	false
): 
	set(_v): _readonly()


var USE_SYSTEM_TITLE_BAR = ConfigFileValue.new(
	_cfg_auto_save, 
	"app", 
	"use_system_titlebar",
	false
): 
	set(_v): _readonly()


var USE_GITHUB = ConfigFileValue.new(
	_cfg_auto_save, 
	"app", 
	"use_github",
	false
): 
	set(_v): _readonly()


func _enter_tree() -> void:
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(DEFAULT_VERSIONS_PATH))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(DEFAULT_DOWNLOADS_PATH))
	_cfg.load(APP_CONFIG_PATH)
	assert(not DEFAULT_VERSIONS_PATH.ends_with("/"))
	assert(not DEFAULT_DOWNLOADS_PATH.ends_with("/"))
	
	AGENT = "Godots/%s (%s) Godot/%s" % [
		VERSION, 
		OS.get_name(), 
		Engine.get_version_info().string
	]
	_setup_scale()


func _setup_scale():
	AUTO_EDSCALE = _get_auto_display_scale()
	var saved_scale = SAVED_EDSCALE.ret(AUTO_EDSCALE)
	EDSCALE = clamp(saved_scale, 0.5, 4)


#https://github.com/godotengine/godot/blob/master/editor/editor_settings.cpp#L1400
func _get_auto_display_scale():
#	if OS.has_feature("macos"):
#		return DisplayServer.screen_get_max_scale()
#	else:
	var screen = DisplayServer.window_get_current_screen()
	if DisplayServer.screen_get_size(screen) == Vector2i():
		return 1.0

	# Use the smallest dimension to use a correct display scale on portrait displays.
	var smallest_dimension = min(DisplayServer.screen_get_size(screen).x, DisplayServer.screen_get_size(screen).y);
	if DisplayServer.screen_get_dpi(screen) >= 192 and smallest_dimension >= 1400:
		# hiDPI display.
		return 2.0
	elif smallest_dimension >= 1700:
		# Likely a hiDPI display, but we aren't certain due to the returned DPI.
		# Use an intermediate scale to handle this situation.
		return 1.5
	elif smallest_dimension <= 800:
		# Small loDPI display. Use a smaller display scale so that editor elements fit more easily.
		# Icons won't look great, but this is better than having editor elements overflow from its window.
		return 0.75
	return 1.0


func save():
	var err = _cfg.save(APP_CONFIG_PATH)
	if err == OK:
		saved.emit() 
	return err


func editor_settings_proxy_get(key, default):
	return _cfg.get_value(_EDITOR_PROXY_SECTION_NAME, key, default)


func editor_settings_proxy_set(key, value):
	_cfg.set_value(_EDITOR_PROXY_SECTION_NAME, key, value)


func _readonly():
	assert(false, "Property is readonly")


func _simplify_path(s: String):
	return s.simplify_path()
