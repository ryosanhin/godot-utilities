# シーン切り替え

`SceneController`は、専用ルートの子シーンを画面演出付きで交換します。切り替え先のシーンと演出の読み込みには[非同期リソース読み込み](../async_resource_load_request/README.md)を使います。

## 設定

1. `scene_management/`と`async_resource_load_request/`、`transition_management/`をプロジェクト直下へ配置します。
2. `scene_controller.tscn`を、切り替え時にも残るシーンにインスタンス化します。子の`TransitionController`は付属シーンで設定済みです。
3. 交換対象のシーンを子に持つNodeを用意し、エディターで`_main_scene_parent`へ設定します。コントローラーは交換対象の配下から外して配置します。
4. 初期シーンがある場合は、起動前に専用ルートの子としてシーンをインスタンス化します。

> **ノードの寿命と配置**
> 専用ルートと `TransitionController` はエディターで事前に設定してください。`SceneController` の `_ready()` で設定と配置を確認し、不備は `push_error()` で報告します。設定が揃った状態で `_ready()` を終えてから公開メソッドを呼び出してください。
>
> 利用中は設定したノードを解放せず、シーンツリー内に維持してください。メインシーンのルートは `SceneController` が交換・解放します。常駐側のシーンを片付ける場合は、進行中の切り替えが終わってから行ってください。

## 使い方

ゲーム側で参照を定数にまとめると、エディターの補完から指定できます。どちらの引数にも`res://`パスと`uid://`を使えます。

```gdscript
class ScenePaths:
	const MAIN := "res://scenes/main.tscn"


class TransitionPaths:
	const CIRCLE := "uid://dsa1axpkvfqo0"


func open_main_async(controller: SceneController) -> void:
	var result := await controller.change_main_scene_async(
			ScenePaths.MAIN,
			TransitionPaths.CIRCLE,
	)
	if result != SceneController.ChangeResult.SUCCESS:
		print("シーン切り替え結果: ", result)
```

`get_current_main_scene_path()`は、呼び出した時点で専用ルートの先頭の子にある`scene_file_path`を返します。子がいない場合は空文字列を返します。

`is_loaded(scene_reference)`はUIDまたはパスを受け取り、該当シーンが専用ルートにあるか調べます。

| 戻り値 | 条件 |
| --- | --- |
| `SUCCESS` | 新シーンを追加し、画面を戻し終えた |
| `BUSY` | 別の切り替えを処理中 |
| `ALREADY_CURRENT` | 切り替え先を解決したパスが`get_current_main_scene_path()`の戻り値と一致する |
| `INVALID_SCENE` | シーン参照をプロジェクト内のパスに解決できない |
| `TRANSITION_PREPARATION_FAILED` | 演出を読み込めないか、演出シーンの型・構成が不正。画面を覆う前に終了する |
| `LOAD_FAILED` | 切り替え先の`PackedScene`を読み込めないか、シーンを生成できない |
| `ADD_FAILED` | 新シーンを生成した後、専用ルートへ追加できない |

`LOAD_FAILED`と`ADD_FAILED`は、画面を戻して入力遮断を解除した後に返します。`ADD_FAILED`の場合は、生成した新シーンがまだ有効なら解放します。

## 通知

すべての通知は、切り替え先の正規化した`res://`パスを引数に取ります。

- `scene_change_started` は演出の準備が完了し、画面を覆う直前に通知します。
- `main_scene_added` は画面を覆った状態で、新シーンの追加を確認し、旧シーンを専用ルートから外して解放を予約した後に通知します。この時点で`get_current_main_scene_path()`から新シーンのパスを取得できます。シーン独自の非同期初期化や受信側の非同期処理の完了は、必要に応じて利用側で待ちます。
- `scene_change_completed` は、差し替え成功後に画面を戻し、演出と入力遮断を片付けた時点で通知します。

## 演出の作成

付属の円形フェードの調整や独自の演出の作成方法は[画面切り替え演出](../transition_management/README.md)を参照してください。
