package client

import "core:log"
import "core:net"

import rl "vendor:raylib"

import "../common"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 700
TITLE :: "Tic Tac Toe"

main :: proc() {
	logger := log.create_console_logger()
	defer log.destroy_console_logger(logger)
	context.logger = logger

	log.info("Starting client.")

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, TITLE)

	socket, connect_err := connect(net.IP4_Address{127, 0, 0, 1}, 9090)
	log.assertf(connect_err == nil, "Failed to connect to server: %v.", connect_err)
	defer net.close(socket)

	payloads: [dynamic]common.Payload
	defer delete(payloads)

	ack_count, ack_err := recv(socket, &payloads)
	log.assertf(
		ack_count == 1 && ack_err == nil,
		"Failed to get player id from server. Ack count: %v. Err: %v.",
		ack_count,
		ack_err,
	)

	payload := pop_front(&payloads)
	init_payload, ok := payload.(common.ServerPayload)
	log.assertf(ok, "Received data is not initialization payload.")
	init, ok_init := init_payload.(common.ConnectAck)
	log.assertf(ok_init, "Received data is not initialization payload.")

	pawn := init.pawn
	state := init.state
	my_turn: bool
	ready: bool
	log.infof("Connected. Received pawn %v.", pawn)

	anination_board: AnimationBoard
	crossing_animation: Animation
	hovered_cell: [2]int

	// if joined a running game, animation start animation for placed pawns
	switch s in state {
	case common.PlayState:
		my_turn = s.player == pawn
		for i in 0 ..= 2 {
			for j in 0 ..= 2 {
				if s.board[i][j] != .None {
					anination_board[i][j] = create_pawn_animation()
				}
			}
		}
	case common.WinState:
		ready = bool(s.player_ready[int(pawn) - 1])
	}

	for !rl.WindowShouldClose() {
		frametime_s := rl.GetFrameTime()
		mouse_pos := rl.GetMousePosition()

		// Update animations
		for i in 0 ..= 2 {
			for j in 0 ..= 2 {
				advance_animation(&anination_board[i][j], frametime_s)
			}
		}

		// Listen net messages
		clear(&payloads)
		buf: [1024]byte
		read: int
		read_err: net.Network_Error
		for read, read_err = net.recv(socket, buf[:]);
		    read > 0 && read_err == nil;
		    read, read_err = net.recv(socket, buf[:]) {

			common.deserialize_packets(buf[:read], &payloads)
		}

		// process net messages
		for p in payloads {
			spl := p.(common.ServerPayload) or_continue
			gstate := spl.(common.State) or_continue

			state = gstate

			switch stt_t in state {
			case common.PlayState:
				my_turn = stt_t.player == pawn

				for x in 0 ..= 2 {
					for y in 0 ..= 2 {
						if anination_board[x][y].duration_s == 0 && stt_t.board[x][y] != .None {
							anination_board[x][y] = create_pawn_animation()
						}
						if stt_t.turn == 0 {
							anination_board[x][y].duration_s = 0
						}
					}
				}

				if stt_t.turn == 0 {
					crossing_animation.duration_s = 0
				}
			case common.WinState:
				ready = bool(stt_t.player_ready[int(pawn) - 1])

				if crossing_animation.duration_s == 0 {
					crossing_animation = create_crossing_animation()
				}
			}
		}

		// Logic
		switch &s in state {
		case common.PlayState:
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

				payload := common.ClientPayload {
					pawn = pawn,
					type = common.Move {
						turn = s.turn,
						x = u8(hovered_cell.x),
						y = u8(hovered_cell.y),
					},
				}
				send_err := send(socket, payload)
				if send_err != nil {
					log.errorf("Failed to send data to server: %v.", send_err)
					// TODO: handle disconnection
				}
			}
		case common.WinState:
			if (mouse_pos.y < HEADER_HEIGHT && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)) ||
			   rl.IsKeyPressed(rl.KeyboardKey.ENTER) {

				send_err := send(
					socket,
					common.ClientPayload{pawn = pawn, type = common.Restart{}},
				)
				if send_err != nil {
					log.errorf("Failed to send data to server: %v.", send_err)
				}
			} else {
				advance_animation(&crossing_animation, frametime_s)
			}
		}

		// Render 
		rl.BeginDrawing()
		rl.ClearBackground(BG_COLOR)

		render_header(&state, my_turn, ready)
		render_grid()

		switch &stt_t in state {
		case common.PlayState:
			render_board(&stt_t.board, &anination_board)
			if my_turn {
				render_hovered_cell(hovered_cell)
			}
		case common.WinState:
			render_board(&stt_t.board, &anination_board)
			if stt_t.winner != .None {
				render_crossing_line(stt_t.line, crossing_animation, pawn_color[stt_t.winner])
			}
		}

		rl.EndDrawing()
	}

	send(socket, common.ClientPayload{pawn = pawn, type = common.Disconnect{}})

	rl.CloseWindow()

	log.info("Closing client.")
}
