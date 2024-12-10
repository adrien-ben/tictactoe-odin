package common

import "core:math/rand"

Board :: distinct [3][3]Pawn

Pawn :: enum u8 {
	None,
	X,
	O,
}

State :: union #no_nil {
	PlayState,
	WinState,
}

PlayState :: struct {
	board:  Board,
	player: Pawn,
	turn:   u8,
}

WinState :: struct {
	board:        Board,
	line:         [2][2]u8,
	player_ready: [2]b8,
	winner:       Pawn,
}

create_play_state :: proc() -> State {
	return PlayState{board = Board{}, turn = 0, player = Pawn(rand.int_max(len(Pawn) - 1) + 1)}
}

has_won :: proc(board: ^Board, p: Pawn, x: u8, y: u8) -> (won: bool = true, line: [2][2]u8) {
	if board[0][y] == p && board[1][y] == p && board[2][y] == p {
		line = {{0, y}, {2, y}}
		return
	}
	if board[x][0] == p && board[x][1] == p && board[x][2] == p {
		line = {{x, 0}, {x, 2}}
		return
	}
	if board[0][0] == p && board[1][1] == p && board[2][2] == p {
		line = {{0, 0}, {2, 2}}
		return
	}
	if board[2][0] == p && board[1][1] == p && board[0][2] == p {
		line = {{2, 0}, {0, 2}}
		return
	}

	won = false
	return
}

is_board_full :: proc(board: ^Board) -> bool {
	for r in 0 ..= 2 {
		for c in 0 ..= 2 {
			if board[r][c] == .None {
				return false
			}
		}
	}
	return true
}
