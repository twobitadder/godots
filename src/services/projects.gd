class Projects extends RefCounted:
	const dict = preload("res://src/extensions/dict.gd")
	
	var _cfg = ConfigFile.new()
	var _projects = {}
	var _cfg_path
	var _default_icon
	var _local_editors
	
	func _init(cfg_path, local_editors, default_icon) -> void:
		_cfg_path = cfg_path
		_local_editors = local_editors
		_default_icon = default_icon
	
	func add(project_path, editor_path) -> Project:
		var project = Project.new(
			ConfigFileSection.new(project_path, _cfg),
			ExternalProjectInfo.new(project_path, _default_icon),
			_local_editors
		)
		project.favorite = false
		project.editor_path = editor_path
		_projects[project_path] = project
		return project
	
	func all() -> Array[Project]:
		var result: Array[Project] = []
		for x in _projects.values():
			result.append(x)
		return result
	
	func retrieve(project_path) -> Project:
		return _projects[project_path]
	
	func has(project_path) -> bool:
		return _projects.has(project_path)
	
	func erase(project_path) -> void:
		_projects.erase(project_path)
		_cfg.erase_section(project_path)
	
	func get_editors_to_bind():
		return _local_editors.as_option_button_items()
	
	func get_all_tags():
		var set = Set.new()
		for project in _projects.values():
			for tag in project.tags:
				set.append(tag.to_lower())
		return set.values()
	
	
	func load() -> Error:
		dict.clear_and_free(_projects)
		var err = _cfg.load(_cfg_path)
		if err: return err
		for section in _cfg.get_sections():
			_projects[section] = Project.new(
				ConfigFileSection.new(section, _cfg),
				ExternalProjectInfo.new(section, _default_icon),
				_local_editors
			)
		return Error.OK
	
	func save() -> Error:
		return _cfg.save(_cfg_path)


class Project:
	const dir = preload("res://src/extensions/dir.gd")
	
	signal internals_changed
	signal loaded
	
	var show_edit_warning:
		get: return _section.get_value("show_edit_warning", true)
		set(value): _section.set_value("show_edit_warning", value)
	
	var path:
		get: return _section.name
	
	var name:
		get: return _external_project_info.name
	
	var editor_name:
		get: return _get_editor_name()
	
	var icon:
		get: return _external_project_info.icon

	var favorite:
		get: return _section.get_value("favorite", false)
		set(value): _section.set_value("favorite", value)
	
	var editor_path:
		get: return _section.get_value("editor_path", "")
		set(value): 
			show_edit_warning = true
			_section.set_value("editor_path", value)
	
	var has_invalid_editor:
		get: return not _local_editors.editor_is_valid(editor_path)
	
	var is_valid:
		get: return dir.path_is_valid(path)
	
	var editors_to_bind:
		get: return _local_editors.as_option_button_items()
	
	var is_missing:
		get: return _external_project_info.is_missing
	
	var is_loaded:
		get: return _external_project_info.is_loaded
	
	var tags:
		set(value): _external_project_info.tags = value
		get: return _external_project_info.tags
	
	var last_modified:
		get: return _external_project_info.last_modified
	
	var features:
		get: return _external_project_info.features
	
	var _external_project_info: ExternalProjectInfo
	var _section: ConfigFileSection
	var _local_editors
	
	func _init(
		section: ConfigFileSection, 
		project_info: ExternalProjectInfo,
		local_editors
	) -> void:
		self._section = section
		self._external_project_info = project_info
		self._local_editors = local_editors
		self._local_editors.editor_removed.connect(
			_check_editor_changes
		)
		self._local_editors.editor_name_changed.connect(_check_editor_changes)
		project_info.loaded.connect(func(): loaded.emit())
	
	func load():
		_external_project_info.load()
	
	func _get_editor_name():
		if has_invalid_editor:
			return '<null>'
		else:
			return _local_editors.retrieve(editor_path).name

	func _check_editor_changes(editor_path):
		if editor_path == self.editor_path:
			emit_internals_changed()
	
	func emit_internals_changed():
		internals_changed.emit()


class ExternalProjectInfo extends RefCounted:
	signal loaded
	
	var icon:
		get: return _icon

	var name:
		get: return _name

	var last_modified:
		get: return _last_modified
	
	var is_loaded:
		get: return _is_loaded
	
	var is_missing:
		get: return _is_missing
	
	var tags:
		set(value):
			_tags = value
			if is_missing:
				return
			var cfg = ConfigFile.new()
			var err = cfg.load(_project_path)
			if not err:
				var set = Set.new()
				for tag in _tags:
					set.append(tag.to_lower())
				cfg.set_value(
					"application", 
					"config/tags", 
					PackedStringArray(set.values())
				)
				cfg.save(_project_path)
		get: return Set.of(_tags).values()
	
	var features:
		get: return _features
	
	var _is_loaded = false
	var _project_path
	var _default_icon
	var _icon
	var _name = "Loading..."
	var _last_modified
	var _is_missing = false
	var _tags = []
	var _features = []
	
	func _init(project_path, default_icon):
		_project_path = project_path
		_default_icon = default_icon
		_icon = default_icon
	
	func load():
		var cfg = ConfigFile.new()
		var err = cfg.load(_project_path)
		
		_name = cfg.get_value("application", "config/name", "Missing Project")
		_tags = cfg.get_value("application", "config/tags", [])
		_features = cfg.get_value("application", "config/features", [])
		
		_last_modified = FileAccess.get_modified_time(_project_path)
		_icon = _load_icon(cfg)
		_is_missing = bool(err)
		
		_is_loaded = true
		loaded.emit()
	
	func _load_icon(cfg):
		var result = _default_icon
		var icon_path: String = cfg.get_value("application", "config/icon", "")
		if not icon_path: return result
		icon_path = icon_path.replace("res://", self._project_path.get_base_dir() + "/")
		
		if FileAccess.file_exists(icon_path):
			var icon_image = Image.new()
			var err = icon_image.load(icon_path)
			if not err:
				icon_image.resize(
					_default_icon.get_width(), _default_icon.get_height(), Image.INTERPOLATE_LANCZOS
				)
				result = ImageTexture.create_from_image(icon_image)
		return result
