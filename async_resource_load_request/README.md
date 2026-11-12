# 非同期リソース読み込み

`AsyncResourceLoader`は、1インスタンスで1件のリソースを非同期に読み込む補助クラスです。UIDまたは通常のリソースパスを指定できます。

## 使い方

以下はNodeのメソッド内での使用例です。

```gdscript
const AsyncResourceLoader := preload("res://async_resource_loading/async_resource_loader.gd")


func load_scene_async() -> PackedScene:
	var request := AsyncResourceLoader.new(
		"res://scenes/main.tscn",
		get_tree().process_frame,
		"PackedScene",
	)
	if not request.is_completed():
		await request.completed
	if not request.is_successful():
		push_error(request.format_error())
		return null
	return request.resource as PackedScene
```

- 生成時に読み込みを開始します。すでに完了している場合があるため、待機前に`is_completed()`を確認します。
- 第2引数には、読み込み中も繰り返し発火するシグナルを渡します。発行元は完了するまで維持してください。
- 成功・失敗のどちらでも`completed`を通知します。成功時のリソースは`resource`で取得します。
- 失敗理由は`error_code`と`format_error()`で確認できます。
- 空文字列・解決できないUID・存在しないリソースパスは、`ErrorCode.INVALID_REFERENCE`として扱います。指定した参照は`resource_reference`に保持し、エラー説明にも含めます。
- 第3引数は型のヒントです。結果の型は保証されないため、利用側でキャストなどを行います。

他モジュールへの依存はありません。エディタープラグインの有効化は不要です。
