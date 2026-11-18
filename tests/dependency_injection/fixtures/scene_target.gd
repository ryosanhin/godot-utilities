extends Node

var received: Array[Object] = []
var call_count := 0


## 受け取った依存と呼び出し回数を記録する。[br]
## [param node_instance]: ノードの依存[br]
## [param service_instance]: 参照カウントされる依存
func inject_dependency(
	node_instance: DependencyInjectionTestNodeService,
	service_instance: DependencyInjectionTestService,
) -> void:
	received = [node_instance, service_instance]
	call_count += 1
