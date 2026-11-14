# 非同期リソース読み込み

`AsyncResourceLoader`は、1インスタンスでプロジェクト内のリソースを1件非同期に読み込む補助クラスです。UID、`res://` パス、プロジェクトルートからの相対パス、プロジェクト内を指す絶対パスを指定できます。

## 使い方

以下はNodeのメソッド内での使用例です。

```gdscript
const AsyncResourceLoader := preload("res://async_resource_load_request/async_resource_load_request.gd")


func load_scene_async() -> PackedScene:
	var request := AsyncResourceLoader.new("res://scenes/main.tscn", "PackedScene")
	return (await request.get_resource_async()) as PackedScene
```

- 生成時に読み込みを開始します。`await request.get_resource_async()` は読み込み中だけ待機し、成功時はリソース、失敗時は `null` を返します。完了済みならその場で結果を返します。
- 実行中の `SceneTree` を `Engine.get_main_loop()` から取得し、読み込み中は `process_frame` ごとに状態を確認します。`SceneTree` を取得できない場合は、読み込みを開始する前に `ErrorCode.SCENE_TREE_UNAVAILABLE` で完了します。
- 呼び出し元がリクエストへの参照を手放しても、メインの `SceneTree` がフレームを進める間は、結果を回収するまでリクエストを内部で保持します。
- 完了をシグナルで扱う場合は `is_completed()` を先に確認し、未完了なら `completed` を待ちます。成功時のリソースは `resource` でも参照できます。
- 失敗理由は`error_code`と`format_error()`で確認できます。
- 正規化した `res://` パスを `resource_path` で取得できます。読み込み要求とエラー説明にはこのパスを使います。
- 空文字列、解決できないUID、プロジェクト外を指すパス（`user://` を含む）、存在しないリソースは `ErrorCode.INVALID_REFERENCE` として扱います。パスに解決できなかった場合は `resource_path` が空文字列になり、エラー説明には元の入力が表示されます。
- 第2引数は省略可能な型のヒントです。型が異なる場合もキャスト結果は `null` になるため、読み込み失敗と区別する場合はキャスト前の戻り値を確認します。

他モジュールへの依存はありません。エディタープラグインの有効化は不要です。
