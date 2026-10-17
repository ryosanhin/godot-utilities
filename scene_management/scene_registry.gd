extends Resource
class_name SceneRegistry

@export var _data_dict: Dictionary[StringName, SceneEntry] = {}


func get_scene_data(id: StringName) -> SceneEntry:
	if not _data_dict.has(id):
		push_error("SceneEntryが登録されていません: %s" % id)
		return null

	return _data_dict[id]
