package server

import "core:flags"
import "core:log"
import "core:net"
import "core:os"
import "core:time"

import "../common"

Player :: struct {
	sock:      net.TCP_Socket,
	endpoint:  net.Endpoint,
	connected: bool,
}

Args :: struct {
	port: uint,
}

main :: proc() {
	logger := log.create_console_logger()
	defer log.destroy_console_logger(logger)
	context.logger = logger

	log.info("Starting server...")

	args: Args
	flags.parse_or_exit(&args, os.args[:])

	socket := start_server(args.port)
	defer net.close(socket)

	players: [2]Player

	payloads: [dynamic]common.Payload
	defer delete(payloads)

	state := common.create_play_state()

	// main loop
	for {
		// wait for all players
		for &p, i in players {
			if !p.connected {
				pawn := common.Pawn(i + 1)
				log.infof("Waiting for player %v to connect...", pawn)
				p = wait_for_player(socket, pawn, state) or_continue

				log.infof("Player %v connected.", pawn)
			}
		}

		// reading commands for both players
		clear(&payloads)
		for &p in players {
			read_err := read_all_packets(p, &payloads)
			if read_err != nil {
				log.errorf("Failed to read commands: %v. Disconnecting player.", read_err)
				reset_player(&p)
			}
		}

		state_changed: bool

		for payload in payloads {
			cpl := payload.(common.ClientPayload) or_continue

			switch cpl_t in cpl.type {
			case common.Move:
				pstate := (&state.(common.PlayState)) or_continue

				pawn := cpl.pawn

				is_valid_move(cpl_t, pstate^, pawn) or_continue

				// update state
				x := cpl_t.x
				y := cpl_t.y
				pstate.board[x][y] = pawn

				if won, line := common.has_won(&pstate.board, pawn, x, y); won {
					state = common.WinState {
						board  = pstate.board,
						winner = pawn,
						line   = line,
					}
				} else if common.is_board_full(&pstate.board) {
					state = common.WinState {
						board  = pstate.board,
						winner = .None,
					}
				} else {
					pstate.player = .O if pstate.player == .X else .X
					pstate.turn += 1
				}

				state_changed = true
			case common.Restart:
				wstate := (&state.(common.WinState)) or_continue

				wstate.player_ready[int(cpl.pawn) - 1] = true
				if wstate.player_ready[0] && wstate.player_ready[1] {
					state = common.create_play_state()

				}
				state_changed = true

			case common.Disconnect:
				log.infof("Player %v disconnected.", cpl.pawn)
				reset_player(&players[int(cpl.pawn) - 1])
			}
		}

		if state_changed {
			// send new state to players
			for p, i in players {
				pawn := common.Pawn(i + 1)
				send_err := send(p.sock, state)
				if send_err != nil {
					log.errorf("Failed to send game state to client %v.", pawn)
				}
			}
		}

		time.sleep(33 * time.Millisecond)
	}

	for &p in players {
		if p.connected {
			reset_player(&p)
		}
	}
	log.info("Closing server.")
}

start_server :: proc(port: uint) -> net.TCP_Socket {
	endpoint := net.Endpoint {
		address = net.IP4_Address{0, 0, 0, 0},
		port    = int(port),
	}

	socket, err := net.listen_tcp(endpoint, backlog = 1000)
	log.assertf(err == nil, "Failed to create tcp socket: %v.", err)

	block_err := net.set_blocking(socket, false)
	log.assertf(block_err == nil, "Failed to set socket to non blocking: %v.", block_err)

	bound_to, bound_err := net.bound_endpoint(socket)
	log.assertf(bound_err == nil, "Failed to bind tcp socket to endpoint: %v.", err)
	log.infof("Server started and listening on port %v.", bound_to.port)

	return socket
}

is_valid_move :: proc(mv: common.Move, state: common.PlayState, pawn: common.Pawn) -> bool {
	return(
		mv.x <= 2 &&
		mv.y <= 2 &&
		state.board[mv.x][mv.y] == .None &&
		mv.turn == state.turn &&
		pawn == state.player \
	)
}

reset_player :: proc(player: ^Player) {
	net.close(player.sock)
	player^ = {}
}

wait_for_player :: proc(
	socket: net.TCP_Socket,
	pawn: common.Pawn,
	state: common.State,
) -> (
	c: Player,
	ok: bool,
) {
	for {
		accept_err: net.Network_Error
		c.sock, c.endpoint, accept_err = net.accept_tcp(socket)

		if accept_err != nil && accept_err != net.Accept_Error.Would_Block {
			log.errorf("Failed to accept incoming connection: %v.", accept_err)
			return
		}

		if accept_err == nil {
			block_err := net.set_blocking(c.sock, false)
			if block_err != nil {
				log.errorf("Failed to set player's socket to non blocking: %v.", block_err)
				return
			}
		}

		if accept_err == nil {
			log.info("Player connecting...")

			payload: common.ConnectAck
			payload.pawn = pawn
			payload.state = state

			send_err := send(c.sock, payload)
			if send_err != nil {
				log.errorf("Failed to send new player its id: %v.", send_err)
				reset_player(&c)
				return
			}

			c.connected = true
			ok = true
			return
		}

		time.sleep(100 * time.Millisecond)
	}
}

send :: proc(socket: net.TCP_Socket, payload: common.ServerPayload) -> net.Network_Error {
	return common.send(socket, payload)
}

read_all_packets :: proc(player: Player, payloads: ^[dynamic]common.Payload) -> net.Network_Error {
	buf: [1024]byte
	read: int
	net_err: net.Network_Error

	for read, net_err = net.recv(player.sock, buf[:]);
	    read > 0 && net_err == nil;
	    read, net_err = net.recv(player.sock, buf[:]) {
		common.deserialize_packets(buf[:read], payloads)
	}

	TCP_RECV_WOULD_BLOCK_ERR ::
		net.TCP_Recv_Error.Would_Block when ODIN_OS == .Windows else net.TCP_Recv_Error.Timeout

	if net_err != nil && net_err != TCP_RECV_WOULD_BLOCK_ERR {
		log.errorf("Failed to read player command: %v", net_err)
		return net_err
	}

	return nil
}
