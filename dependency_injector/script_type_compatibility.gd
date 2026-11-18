extends RefCounted


## [param actual_type] が [param expected_type] 自身、またはその派生型であるかを返す。[br]
## いずれかの引数が [code]null[/code] の場合は、互換性がないものとして [code]false[/code] を返す。
static func is_same_or_derived_from(
	actual_type: Script,
	expected_type: Script,
) -> bool:
	if actual_type == null or expected_type == null:
		return false

	var current_type := actual_type
	while current_type != null:
		if current_type == expected_type:
			return true
		current_type = current_type.get_base_script()

	return false
