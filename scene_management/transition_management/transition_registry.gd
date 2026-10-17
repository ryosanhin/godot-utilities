extends Resource
class_name TransitionRegistry

@export var _entries: Dictionary[StringName, TransitionEntry] = {}


func get_entry(id: StringName) -> TransitionEntry:
	if not _entries.has(id):
		push_error("TransitionEntryが登録されていません:", id)
		return null
	return _entries[id]
