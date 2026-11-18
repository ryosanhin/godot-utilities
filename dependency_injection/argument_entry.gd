extends RefCounted

var arg_name: StringName
var service_type: Script
var arg_type: int


## 宣言された引数の情報を保持する。[br]
## [param init_arg_name]: 引数名[br]
## [param init_service_type]: 注入に使うスクリプト型。未対応の場合はnull[br]
## [param init_arg_type]: 引数のVariant型
func _init(
	init_arg_name: StringName,
	init_service_type: Script,
	init_arg_type: int,
) -> void:
	arg_name = init_arg_name
	service_type = init_service_type
	arg_type = init_arg_type


## 引数名と型情報を確認するための文字列を返す。
func _to_string() -> String:
	return (
			"name: %s, class_name: %s, type: %d (%s)"
			% [
				arg_name,
				(
						type_string(arg_type)
						if service_type == null
						else service_type.get_global_name()
				),
				arg_type,
				type_string(arg_type),
			]
	)
