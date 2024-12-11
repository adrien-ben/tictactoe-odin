package client

import "../common"

AppState :: union {
	OnlineGameState,
}

update_app_state :: proc(state: ^AppState) {
	switch &s in state {
	case OnlineGameState:
		update_online_state(&s)
	}
}

render_app_state :: proc(state: ^AppState) {
	switch &s in state {
	case OnlineGameState:
		render_online_state(&s)
	}
}

destroy_app_state :: proc(state: ^AppState) {
	switch &s in state {
	case OnlineGameState:
		destroy_online_state(&s)
	}
}

GameState :: union #no_nil {
	PlayState,
	WinState,
}

PlayState :: struct {
	board:   common.Board,
	my_turn: bool,
	turn:    u8,
}

WinState :: struct {
	board:  common.Board,
	line:   [2][2]u8,
	ready:  bool,
	winner: common.Pawn,
}

to_local_state :: proc(server_state: common.State, pawn: common.Pawn) -> (local_state: GameState) {
	switch ss in server_state {
	case common.PlayState:
		local_state = PlayState {
			board   = ss.board,
			turn    = ss.turn,
			my_turn = ss.player == pawn,
		}
	case common.WinState:
		local_state = WinState {
			board  = ss.board,
			line   = ss.line,
			winner = ss.winner,
			ready  = bool(ss.player_ready[int(pawn) - 1]),
		}
	}
	return
}
