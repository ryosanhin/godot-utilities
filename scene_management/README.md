# シーン切り替え

`SceneController`は、専用ルートの子シーンを画面演出付きで交換します。読み込みには[非同期リソース読み込み](../async_resource_loading/README.md)を使用します。

## 設定

1. `scene_management/`と`async_resource_loading/`をプロジェクト直下へ配置します。
2. `scene_controller.tscn`を、切り替え時にも残るシーンにインスタンス化します。
3. `SceneRegistry`を作成し、`_data_dict`にシーンIDと`SceneEntry`を登録します。`SceneEntry.scene_path`には切り替え先のシーンを指定し、Registryをコントローラーの`_scene_registry`に設定します。
4. 交換対象のシーンだけを子に持つNodeを用意し、`_main_scenes_root`へ設定します。コントローラー自身は交換対象の配下に置かないでください。
5. 子の`TransitionController`に[画面演出のRegistry](transition_management/README.md)を設定します。必要に応じて「編集可能な子」を有効にします。
6. 初期シーンを使う場合は専用ルートへ配置し、そのIDを`init_scene_id`に設定します。このIDを設定するだけではシーンは読み込まれません。

`_transition_controller`は付属シーンで設定済みです。`_transition_duration`は画面を覆う・戻す演出それぞれの秒数です。エディタープラグインの有効化は不要です。

## 使い方

以下はNodeのメソッド内での使用例です。`controller`には配置済みのコントローラーを渡します。

```gdscript
func open_game_async(controller: SceneController) -> void:
	var result := await controller.change_main_scene_async(&"game", &"circle")
	if result != SceneController.ChangeResult.SUCCESS:
		print("シーン切り替え結果: ", result)
```

`game`はSceneRegistry、`circle`はTransitionRegistryへ事前に登録したIDです。

戻り値は`SUCCESS`、`BUSY`、`ALREADY_CURRENT`、`INVALID_SCENE`、`LOAD_FAILED`です。読み込み失敗時は現在のシーンを維持し、画面を戻してから結果を返します。

## 通知

- `scene_change_started`：要求を受け付け、切り替えを開始したとき。
- `scene_replaced`：シーンを追加し、現在のIDを更新した後。画面を戻す演出の前。
- `scene_changed`：画面を戻す演出まで完了したとき。

`scene_replaced`は、切り替え先シーン独自の非同期初期化の完了までは待ちません。
