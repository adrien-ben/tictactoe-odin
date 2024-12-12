package client

import "core:math/rand"

import rl "vendor:raylib"

import "../common"

OfflineGameState :: struct {
	game_state:      GameState,
	anination_board: AnimationBoard,
}

create_offline_state :: proc() -> (s: OfflineGameState) {
	s.game_state = create_play_state()
	return
}

destroy_offline_state :: proc(s: ^OfflineGameState) {
}

update_offline_state :: proc(s: ^OfflineGameState) -> Transition {

	if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
		return .Back
	}

	frametime_s := rl.GetFrameTime()
	mouse_pos := rl.GetMousePosition()

	// Update animations
	for i in 0 ..= 2 {
		for j in 0 ..= 2 {
			advance_animation(&s.anination_board[i][j], frametime_s)
		}
	}

	// Logic
	switch &st in s.game_state {
	case PlayState:
		if (rl.GetMouseDelta() != {0, 0} || rl.IsMouseButtonPressed(rl.MouseButton.LEFT)) &&
		   mouse_pos.y > HEADER_HEIGHT {
			st.hovered_cell.x = int(mouse_pos.x) / (WINDOW_WIDTH / 3)
			st.hovered_cell.y = (int(mouse_pos.y) - HEADER_HEIGHT) / (WINDOW_WIDTH / 3)
		}

		if rl.IsKeyPressed(rl.KeyboardKey.UP) {
			st.hovered_cell.y -= 1
		} else if rl.IsKeyPressed(rl.KeyboardKey.DOWN) {
			st.hovered_cell.y += 1
		} else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
			st.hovered_cell.x -= 1
		} else if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
			st.hovered_cell.x += 1
		}

		st.hovered_cell.x = clamp(st.hovered_cell.x, 0, 2)
		st.hovered_cell.y = clamp(st.hovered_cell.y, 0, 2)

		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) || rl.IsKeyPressed(rl.KeyboardKey.ENTER) {

			if st.board[st.hovered_cell.x][st.hovered_cell.y] != .None do break

			st.board[st.hovered_cell.x][st.hovered_cell.y] = st.player
			s.anination_board[st.hovered_cell.x][st.hovered_cell.y] = create_pawn_animation()

			if won, line := common.has_won(
				&st.board,
				st.player,
				st.hovered_cell.x,
				st.hovered_cell.y,
			); won {
				s.game_state = WinState {
					board              = st.board,
					winner             = st.player,
					line               = line,
					crossing_animation = create_crossing_animation(),
				}
			} else if common.is_board_full(&st.board) {
				s.game_state = WinState {
					board  = st.board,
					winner = .None,
				}
			} else {
				st.player = .O if st.player == .X else .X
			}
		}
	case WinState:
		if (mouse_pos.y < HEADER_HEIGHT && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)) ||
		   rl.IsKeyPressed(rl.KeyboardKey.ENTER) {
			s.game_state = create_play_state()
		} else {
			advance_animation(&st.crossing_animation, frametime_s)
		}
	}

	return .None
}

resume_offline_state :: proc(s: ^OfflineGameState) {
}

render_offline_state :: proc(s: ^OfflineGameState) {
	rl.ClearBackground(BG_COLOR)

	render_offline_header(&s.game_state)
	render_grid()

	switch &st in s.game_state {
	case PlayState:
		render_board(&st.board, &s.anination_board)
		render_hovered_cell(st.hovered_cell)
	case WinState:
		render_board(&st.board, &s.anination_board)
		if st.winner != .None {
			render_crossing_line(st.line, st.crossing_animation, pawn_color[st.winner])
		}
	}
}

@(private = "file")
render_offline_header :: proc(state: ^GameState) {
	text: cstring
	switch s in state {
	case PlayState:
		text = player_turn_msg[s.player]
	case WinState:
		text = win_msg[s.winner]
	}

	message: Maybe(cstring)
	if _, ok := state.(WinState); ok {
		message = RESTART_MSG
	}

	render_ingame_header(text, message)
}

@(private = "file")
GameState :: union #no_nil {
	PlayState,
	WinState,
}

@(private = "file")
PlayState :: struct {
	board:        common.Board,
	player:       common.Pawn,
	hovered_cell: [2]int,
}

@(private = "file")
WinState :: struct {
	board:              common.Board,
	line:               [2][2]u8,
	winner:             common.Pawn,
	crossing_animation: Animation,
}

create_play_state :: proc() -> GameState {
	return PlayState {
		board = common.Board{},
		player = common.Pawn(rand.int_max(len(common.Pawn) - 1) + 1),
	}
}
