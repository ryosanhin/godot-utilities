extends SceneTree

const TestHelper := preload("res://tests/supports/test_helper.gd")
const SceneTarget := preload("fixtures/scene_target.gd")
const TARGET_SCENE := preload("fixtures/scene_target.tscn")
const ErrorCode := DependencyInjector.ErrorCode

var _helper := TestHelper.new(true)


class ServiceTarget extends RefCounted:
	var received: DependencyInjectionTestService

	## 注入された依存を記録する。[br]
	## [param service]: 対象が要求するサービス
	func inject_dependency(service: DependencyInjectionTestService) -> void:
		received = service


class MockTypeTarget extends RefCounted:
	## 派生型そのものへの明示的な登録が必要なことを確認する。[br]
	## [param _service]: 対象が要求する派生型のサービス
	func inject_dependency(_service: DependencyInjectionTestMockService) -> void:
		pass


class InvalidTypeTarget extends RefCounted:
	var called := false

	## 未対応の引数型で呼び出されないことを確認する。[br]
	## [param _value]: 注入に非対応のネイティブ型の引数
	func inject_dependency(_value: Node) -> void:
		called = true


class EmptyTarget extends RefCounted:
	var call_count := 0

	## 引数のない注入メソッドの呼び出し回数を記録する。
	func inject_dependency() -> void:
		call_count += 1


## テストの実行を予約する。
func _initialize() -> void:
	_run_tests.call_deferred()


## 依存の登録、注入、解除の主要な経路を確認する。
func _run_tests() -> void:
	_test_registration_and_mock()
	_test_detached_scene()
	_test_invalid_registration()
	_test_incomplete_injection()
	_test_injection_method()
	_test_freed_instance_and_clear()
	await _helper.finish(self, "dependency_injector")


## 同じ型の実インスタンスと派生型のモックを別々のInjectorから注入する。
func _test_registration_and_mock() -> void:
	_helper.change_test_name("registration_and_mock")
	var injector := DependencyInjector.new()
	var mock_injector := DependencyInjector.new()
	var service := DependencyInjectionTestService.new()
	var mock := DependencyInjectionTestMockService.new()
	var target := ServiceTarget.new()
	var mock_target := ServiceTarget.new()

	_helper.assert_true(injector.register(DependencyInjectionTestService, service), "同じ型を登録する")
	_helper.assert_true(mock_injector.register(DependencyInjectionTestService, mock), "派生型を基底型で登録する")
	_helper.assert_true(injector.inject(target), "実インスタンスを注入する")
	_helper.assert_true(mock_injector.inject(mock_target), "モックを注入する")
	_helper.assert_same(target.received, service, "実インスタンスが渡る")
	_helper.assert_same(mock_target.received, mock, "同じ対象クラスにモックが渡る")

	_helper.assert_false(mock_injector.inject(MockTypeTarget.new()), "基底型の登録を派生型へ流用しない")
	_helper.assert_equal(mock_injector.get_error_code(), ErrorCode.UNREGISTERED_DEPENDENCY, "派生型は未登録")
	_helper.assert_true(mock_injector.register(DependencyInjectionTestMockService, mock), "派生型としても登録できる")
	_helper.assert_equal(mock_injector.get_error_code(), ErrorCode.OK, "登録に成功するとエラー状態が戻る")
	_helper.assert_true(mock_injector.inject(MockTypeTarget.new()), "派生型の明示的な登録を使う")


## シーンをinstantiate()した直後のノードへ、宣言順で依存を注入する。
func _test_detached_scene() -> void:
	_helper.change_test_name("detached_scene")
	var injector := DependencyInjector.new()
	var service := DependencyInjectionTestService.new()
	var node_service := DependencyInjectionTestNodeService.new()
	var target := TARGET_SCENE.instantiate() as SceneTarget

	_helper.assert_false(target.is_inside_tree(), "対象はシーンツリー参加前")
	_helper.assert_true(injector.register(DependencyInjectionTestService, service), "第2引数の依存を先に登録する")
	_helper.assert_true(injector.register(DependencyInjectionTestNodeService, node_service), "Nodeも登録する")
	_helper.assert_true(injector.inject(target), "ツリー参加前に注入できる")
	_helper.assert_array(target.received, [node_service, service], "注入は登録順にかかわらず宣言順")
	_helper.assert_equal(target.call_count, 1, "全依存を揃えて一度だけ呼ぶ")
	target.free()
	node_service.free()


## class_nameのない型、不正なインスタンス、型不一致、重複を拒否する。
func _test_invalid_registration() -> void:
	_helper.change_test_name("invalid_registration")
	var injector := DependencyInjector.new()
	var service := DependencyInjectionTestService.new()
	var duplicate := DependencyInjectionTestService.new()
	var target := ServiceTarget.new()

	_helper.assert_false(injector.register(null, service), "nullの型を拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.INVALID_SERVICE_TYPE, "登録型が無効")
	_helper.assert_false(injector.register(SceneTarget, service), "class_nameのない登録型を拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.INVALID_SERVICE_TYPE, "登録型はグローバルクラスが必要")
	_helper.assert_false(injector.register(DependencyInjectionTestService, null), "nullのインスタンスを拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.INVALID_INSTANCE, "インスタンスが無効")
	_helper.assert_false(
			injector.register(DependencyInjectionTestService, RefCounted.new()),
			"スクリプトのないインスタンスを拒否する",
	)
	_helper.assert_equal(injector.get_error_code(), ErrorCode.INVALID_INSTANCE, "スクリプトが必要")
	_helper.assert_false(injector.register(DependencyInjectionTestMockService, service), "基底型の逆向き登録を拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.INCOMPATIBLE_SERVICE_TYPE, "インスタンス型が不一致")

	_helper.assert_true(injector.register(DependencyInjectionTestService, service), "最初の登録に成功する")
	_helper.assert_false(injector.register(DependencyInjectionTestService, duplicate), "2回目の同型登録を拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.DUPLICATE_REGISTRATION, "登録が重複")
	_helper.assert_true(injector.inject(target), "最初の登録を使って注入できる")
	_helper.assert_same(target.received, service, "重複登録で上書きされない")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.OK, "注入に成功するとエラー状態が戻る")


## 一部の依存だけを解決できても注入メソッドを呼ばない。
func _test_incomplete_injection() -> void:
	_helper.change_test_name("incomplete_injection")
	var injector := DependencyInjector.new()
	var node_service := DependencyInjectionTestNodeService.new()
	var target := TARGET_SCENE.instantiate() as SceneTarget

	_helper.assert_true(injector.register(DependencyInjectionTestNodeService, node_service), "第1引数の依存だけを登録する")
	_helper.assert_false(injector.inject(target), "第2引数の依存がなければ注入は失敗する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.UNREGISTERED_DEPENDENCY, "第2引数の依存が未登録")
	_helper.assert_equal(target.call_count, 0, "注入メソッドは呼ばれない")
	target.free()
	node_service.free()


## 無効な対象、メソッド不在、未対応型、0引数を区別する。
func _test_injection_method() -> void:
	_helper.change_test_name("injection_method")
	var injector := DependencyInjector.new()
	var invalid_target := InvalidTypeTarget.new()
	var empty_target := EmptyTarget.new()

	_helper.assert_false(injector.inject(null), "nullの対象を拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.INVALID_TARGET, "対象が無効")
	_helper.assert_false(injector.inject(1), "Object以外の対象を拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.INVALID_TARGET, "Objectが必要")
	_helper.assert_false(injector.inject(DependencyInjectionTestService.new()), "メソッド不在を検出する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.MISSING_INJECTION_METHOD, "注入メソッドが不在")
	_helper.assert_false(injector.inject(invalid_target), "ネイティブ型の引数を拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.UNSUPPORTED_ARGUMENT_TYPE, "引数型が未対応")
	_helper.assert_false(invalid_target.called, "未対応型のメソッドは呼ばれない")
	_helper.assert_true(injector.inject(empty_target), "0引数でもメソッドがあれば注入できる")
	_helper.assert_equal(empty_target.call_count, 1, "0引数のメソッドも一度だけ呼ぶ")


## 登録済みのNodeが解放された場合を検出し、clear()で登録とエラーを消去する。
func _test_freed_instance_and_clear() -> void:
	_helper.change_test_name("freed_instance_and_clear")
	var injector := DependencyInjector.new()
	var node_service := DependencyInjectionTestNodeService.new()
	var service := DependencyInjectionTestService.new()
	var target := TARGET_SCENE.instantiate() as SceneTarget

	_helper.assert_true(injector.register(DependencyInjectionTestNodeService, node_service), "有効なNodeを登録する")
	_helper.assert_true(injector.register(DependencyInjectionTestService, service), "参照カウントされる依存も登録する")
	node_service.free()
	_helper.assert_false(injector.inject(node_service), "解放済みの注入対象を拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.INVALID_TARGET, "解放済みの対象が無効")
	_helper.assert_false(injector.register(DependencyInjectionTestNodeService, node_service), "解放済みのNodeの登録を拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.INVALID_INSTANCE, "解放済みの登録インスタンスが無効")
	_helper.assert_false(injector.inject(target), "解放済みのNodeの注入を拒否する")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.FREED_INSTANCE, "解放済みと未登録を区別する")
	_helper.assert_equal(target.call_count, 0, "注入メソッドは呼ばれない")

	injector.clear()
	_helper.assert_equal(injector.get_error_code(), ErrorCode.OK, "登録解除でエラーも初期化する")
	_helper.assert_false(injector.inject(target), "登録解除後は依存を注入できない")
	_helper.assert_equal(injector.get_error_code(), ErrorCode.UNREGISTERED_DEPENDENCY, "解放済みNodeの登録が消える")
	_helper.assert_false(injector.inject(ServiceTarget.new()), "RefCountedの登録も消える")
	_helper.assert_true(injector.register(DependencyInjectionTestService, service), "登録解除後に同じ型を再登録できる")
	target.free()
