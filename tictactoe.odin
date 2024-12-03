package main

import "core:math/rand"
import rl "vendor:raylib"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 700
TITLE :: "Tic Tac Toe"

FONT_SIZE :: 50

BG_COLOR :: rl.Color{200, 200, 200, 255}
LINES_COLOR :: rl.BLACK
TEXT_COLOR :: rl.BLACK

HEADER_HEIGHT :: 100
GRID_HEIGHT :: WINDOW_HEIGHT - HEADER_HEIGHT
GRID_THICKNESS :: 3

PAWN_SIZE :: WINDOW_WIDTH / 10
PAWN_THICKNESS :: 6

RESTART_MSG: cstring : "Click here/press Enter to restart"

Board :: distinct [3][3]Pawn

Pawn :: enum {
	None,
	X,
	O,
}

State :: union #no_nil {
	PlayState,
	WinState,
}

PlayState :: struct {
	player: Pawn,
}

WinState :: struct {
	winner: Pawn,
}

player_turn_msg := #partial [Pawn]cstring {
	.O = "O's turn",
	.X = "X's turn",
}
win_msg := [Pawn]cstring {
	.None = "Draw!",
	.O    = "O wins!",
	.X    = "X wins!",
}
pawn_color := #partial [Pawn]rl.Color {
	.O = rl.RED,
	.X = rl.BLUE,
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, TITLE)

	board := create_empty_board()
	state := create_play_state()

	hovered_cell: [2]int

	for !rl.WindowShouldClose() {
		// Logic
		mouse_pos := rl.GetMousePosition()

		switch &s in state {
		case PlayState:
			if (rl.GetMouseDelta() != {0, 0} || rl.IsMouseButtonPressed(rl.MouseButton.LEFT)) &&
			   mouse_pos.y > HEADER_HEIGHT {
				hovered_cell.x = int(mouse_pos.x) / (WINDOW_WIDTH / 3)
				hovered_cell.y = (int(mouse_pos.y) - HEADER_HEIGHT) / (WINDOW_WIDTH / 3)
			}

			if rl.IsKeyPressed(rl.KeyboardKey.UP) {
				hovered_cell.y -= 1
			} else if rl.IsKeyPressed(rl.KeyboardKey.DOWN) {
				hovered_cell.y += 1
			} else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
				hovered_cell.x -= 1
			} else if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
				hovered_cell.x += 1
			}

			hovered_cell.x = clamp(hovered_cell.x, 0, 2)
			hovered_cell.y = clamp(hovered_cell.y, 0, 2)

			if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) ||
			   rl.IsKeyPressed(rl.KeyboardKey.ENTER) {

				p := s.player
				if board[hovered_cell.y][hovered_cell.x] == .None {
					board[hovered_cell.y][hovered_cell.x] = p

					if (has_won(&board, p, hovered_cell.x, hovered_cell.y)) {
						state = WinState {
							winner = p,
						}
					} else if is_board_full(&board) {
						state = WinState {
							winner = .None,
						}
					} else {
						s.player = s.player == .O ? .X : .O
					}
				}
			}
		case WinState:
			if (mouse_pos.y < HEADER_HEIGHT && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)) ||
			   rl.IsKeyPressed(rl.KeyboardKey.ENTER) {
				board = create_empty_board()
				state = create_play_state()
			}
		}


		// Render 
		rl.BeginDrawing()
		rl.ClearBackground(BG_COLOR)

		render_header(&state)
		render_board(&board)
		if ps, ok := state.(PlayState); ok {
			render_hovered_cell(hovered_cell, ps.player)
		}

		rl.EndDrawing()
	}

	rl.CloseWindow()
}

create_play_state :: proc() -> State {
	return PlayState{player = Pawn(rand.int_max(len(Pawn) - 1) + 1)}
}

create_empty_board :: proc() -> Board {
	return Board{0 ..= 2 = {0 ..= 2 = .None}}
}

has_won :: proc(board: ^Board, p: Pawn, x: int, y: int) -> bool {
	return(
		(board[y][0] == p && board[y][1] == p && board[y][2] == p) ||
		(board[0][x] == p && board[1][x] == p && board[2][x] == p) ||
		(board[0][0] == p && board[1][1] == p && board[2][2] == p) ||
		(board[2][0] == p && board[1][1] == p && board[0][2] == p) \
	)

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

render_header :: proc(state: ^State) {
	rl.DrawRectangleLines(0, 0, WINDOW_WIDTH, HEADER_HEIGHT, LINES_COLOR)

	text: cstring
	switch s in state {
	case PlayState:
		text = player_turn_msg[s.player]
	case WinState:
		text = win_msg[s.winner]
	}

	text_width := rl.MeasureText(text, FONT_SIZE)
	text_x: i32 = WINDOW_WIDTH / 2 - text_width / 2
	text_y: i32 = HEADER_HEIGHT / 2 - FONT_SIZE / 2
	rl.DrawText(text, text_x, text_y, FONT_SIZE, TEXT_COLOR)

	if _, ok := state.(WinState); ok {
		font_size: i32 = (FONT_SIZE / 5) * 3
		text_width := rl.MeasureText(RESTART_MSG, font_size)
		text_x: i32 = WINDOW_WIDTH / 2 - text_width / 2
		text_y: i32 = HEADER_HEIGHT - font_size
		rl.DrawText(RESTART_MSG, text_x, text_y, font_size, TEXT_COLOR)
	}
}

render_board :: proc(board: ^Board) {
	// Draw Grid
	grid_pad :: 10
	rl.DrawLineEx(
		rl.Vector2{WINDOW_WIDTH / 3, HEADER_HEIGHT + grid_pad},
		rl.Vector2{WINDOW_WIDTH / 3, WINDOW_HEIGHT - grid_pad},
		GRID_THICKNESS,
		LINES_COLOR,
	)
	rl.DrawLineEx(
		rl.Vector2{2 * WINDOW_WIDTH / 3, HEADER_HEIGHT + grid_pad},
		rl.Vector2{2 * WINDOW_WIDTH / 3, WINDOW_HEIGHT - grid_pad},
		GRID_THICKNESS,
		LINES_COLOR,
	)
	rl.DrawLineEx(
		rl.Vector2{grid_pad, HEADER_HEIGHT + GRID_HEIGHT / 3},
		rl.Vector2{WINDOW_WIDTH - grid_pad, HEADER_HEIGHT + GRID_HEIGHT / 3},
		GRID_THICKNESS,
		LINES_COLOR,
	)
	rl.DrawLineEx(
		rl.Vector2{grid_pad, HEADER_HEIGHT + 2 * GRID_HEIGHT / 3},
		rl.Vector2{WINDOW_WIDTH - grid_pad, HEADER_HEIGHT + 2 * GRID_HEIGHT / 3},
		GRID_THICKNESS,
		LINES_COLOR,
	)

	// draw pawns
	for r in 0 ..= 2 {
		for c in 0 ..= 2 {
			p := board[r][c]
			if p != .None {
				center_x := f32(c * WINDOW_WIDTH / 3) + WINDOW_WIDTH / 6
				center_y := f32(r * GRID_HEIGHT / 3) + GRID_HEIGHT / 6 + HEADER_HEIGHT
				color := pawn_color[p]

				if p == .X {
					rl.DrawLineEx(
						rl.Vector2{center_x - PAWN_SIZE, center_y - PAWN_SIZE},
						rl.Vector2{center_x + PAWN_SIZE, center_y + PAWN_SIZE},
						PAWN_THICKNESS,
						color,
					)
					rl.DrawLineEx(
						rl.Vector2{center_x - PAWN_SIZE, center_y + PAWN_SIZE},
						rl.Vector2{center_x + PAWN_SIZE, center_y - PAWN_SIZE},
						PAWN_THICKNESS,
						color,
					)
				} else {
					rl.DrawCircle(i32(center_x), i32(center_y), PAWN_SIZE, color)
					rl.DrawCircle(
						i32(center_x),
						i32(center_y),
						PAWN_SIZE - PAWN_THICKNESS,
						BG_COLOR,
					)
				}
			}


		}
	}
}

render_hovered_cell :: proc(pos: [2]int, p: Pawn) {
	if pos.x < 0 || pos.x > 2 || pos.y < 0 || pos.y > 2 {
		return
	}
	rl.DrawRectangleLinesEx(
		rl.Rectangle {
			x = f32(pos.x * WINDOW_WIDTH / 3),
			y = f32(HEADER_HEIGHT + pos.y * GRID_HEIGHT / 3),
			width = WINDOW_WIDTH / 3,
			height = GRID_HEIGHT / 3,
		},
		PAWN_THICKNESS,
		pawn_color[p],
	)
}
