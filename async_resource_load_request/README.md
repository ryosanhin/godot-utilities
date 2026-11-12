# 非同期リソース読み込み

`AsyncResourceLoader`は、1インスタンスでプロジェクト内のリソースを1件非同期に読み込む補助クラスです。UID、`res://` パス、プロジェクトルートからの相対パス、プロジェクト内を指す絶対パスを指定できます。

## 使い方

以下はNodeのメソッド内での使用例です。

```gdscript
const AsyncResourceLoader := preload("res://async_resource_load_request/async_resource_load_request.gd")


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
- 正規化した `res://` パスを `resource_path` で取得できます。読み込み要求とエラー説明にはこのパスを使います。
- 空文字列、解決できないUID、プロジェクト外を指すパス（`user://` を含む）、存在しないリソースは `ErrorCode.INVALID_REFERENCE` として扱います。パスに解決できなかった場合は `resource_path` が空文字列になり、エラー説明には元の入力が表示されます。
- 第3引数は型のヒントです。結果の型は保証されないため、利用側でキャストなどを行います。

他モジュールへの依存はありません。エディタープラグインの有効化は不要です。
