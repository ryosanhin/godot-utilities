extends "res://scene_management/transition_management/transition_effect.gd"

enum Phase {
	PREPARED,
	COVERING,
	COVERED,
	REVEALING,
	REVEALED,
}

var phase := Phase.PREPARED


## この演出はコードで再生するため、AnimationPlayerの設定を必要としない。
func is_configured() -> bool:
	return true


## カバーを開始し、次フレームまで差し替えを待たせる。
func cover_async() -> void:
	phase = Phase.COVERING
	await get_tree().process_frame
	phase = Phase.COVERED


## リビールを開始し、次フレームで完了する。
func reveal_async() -> void:
	phase = Phase.REVEALING
	await get_tree().process_frame
	phase = Phase.REVEALED
