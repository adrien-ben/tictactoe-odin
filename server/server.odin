package server

import "core:log"
import "core:math/rand"
import "core:net"
import "core:time"

import "../common"

MAX_PLAYER_COUNT :: 2

Client :: struct {
	id:        u32,
	sock:      net.TCP_Socket,
	endpoint:  net.Endpoint,
	connected: bool,
}

Player :: struct {
	client_index: int,
	pawn:         common.Pawn,
}

main :: proc() {
	logger := log.create_console_logger()
	defer log.destroy_console_logger(logger)
	context.logger = logger

	log.info("Starting server...")

	endpoint, parsed := net.parse_endpoint("127.0.0.1:9090")
	log.assertf(parsed, "Failed to parse endpoint.")

	socket, err := net.listen_tcp(endpoint, backlog = 1000)
	log.assertf(err == nil, "Failed to create tcp socket: %v.", err)
	defer net.close(socket)

	block_err := net.set_blocking(socket, false)
	log.assertf(block_err == nil, "Failed to set socket to non blocking: %v.", block_err)

	bound_to, bound_err := net.bound_endpoint(socket)
	log.assertf(bound_err == nil, "Failed to bind tcp socket to endpoint: %v.", err)
	log.infof("Server started and listening on port %v.", bound_to.port)

	clients: [MAX_PLAYER_COUNT]Client
	players: map[u32]Player
	defer delete(players)

	payloads: [dynamic]common.Payload
	defer delete(payloads)

	state := common.create_play_state()

	// main loop
	for {
		// wait for all players
		for &c, i in clients {
			if !c.connected {
				log.infof("Waiting for player %v to connect...", i)
				player: Player = {
					client_index = i,
					pawn         = common.Pawn(i + 1),
				}
				c = wait_for_client(socket, player, state) or_continue
				players[c.id] = player

				log.infof("Player %v connected. Has pawn %v.", c.id, players[c.id].pawn)
			}
		}

		// reading commands for both players
		clear(&payloads)
		for &c in clients {
			read_err := read_all_packets(c, &payloads)
			if read_err != nil {
				log.errorf("Failed to read commands: %v. Disconnecting player.", read_err)
				reset_client(&c)
				delete_key(&players, c.id)
			}
		}

		state_changed: bool

		for payload in payloads {
			cpl := payload.(common.ClientPayload) or_continue

			switch cpl_t in cpl.type {
			case common.Move:
				pstate := (&state.(common.PlayState)) or_continue

				player := players[cpl.player_id]
				is_valid_move(cpl_t, pstate^, player) or_continue

				// update state
				x := cpl_t.x
				y := cpl_t.y
				pstate.board[x][y] = player.pawn

				if won, line := common.has_won(&pstate.board, player.pawn, x, y); won {
					state = common.WinState {
						board  = pstate.board,
						winner = player.pawn,
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

				wstate.player_ready[players[cpl.player_id].client_index] = true
				if wstate.player_ready[0] && wstate.player_ready[1] {
					state = common.create_play_state()

				}
				state_changed = true

			case common.Disconnect:
				log.infof("Player %v disconnected.", cpl.player_id)
				reset_client(&clients[players[cpl.player_id].client_index])
				delete_key(&players, cpl.player_id)
			}
		}

		if state_changed {
			// send new state to players
			for c in clients {
				send_err := send_state(c, players[c.id], state)
				if send_err != nil {
					log.errorf("Failed to send game state to client %v.", c.id)
				}
			}
		}

		time.sleep(33 * time.Millisecond)
	}

	log.info("Closing server.")
}

is_valid_move :: proc(mv: common.Move, state: common.PlayState, player: Player) -> bool {
	return(
		mv.x <= 2 &&
		mv.y <= 2 &&
		state.board[mv.x][mv.y] == .None &&
		mv.turn == state.turn &&
		player.pawn == state.player \
	)
}

reset_client :: proc(client: ^Client) {
	net.close(client.sock)
	client^ = {}
}

wait_for_client :: proc(
	socket: net.TCP_Socket,
	player: Player,
	state: common.State,
) -> (
	c: Client,
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
			log.info("Player connecting...")

			my_turn: b8
			#partial switch s in state {
			case common.PlayState:
				my_turn = s.player == player.pawn
			}

			payload: common.ConnectAck
			payload.player_id = u32(rand.int31())
			payload.state = {
				my_turn = my_turn,
				state   = state,
			}

			send_err := send(c.sock, payload)
			if send_err != nil {
				log.errorf("Failed to send new player its id: %v.", send_err)
				reset_client(&c)
				return
			}

			c.id = payload.player_id
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

read_all_packets :: proc(client: Client, payloads: ^[dynamic]common.Payload) -> net.Network_Error {
	buf: [1024]byte
	read: int
	net_err: net.Network_Error

	for read, net_err = net.recv(client.sock, buf[:]);
	    read > 0 && net_err == nil;
	    read, net_err = net.recv(client.sock, buf[:]) {
		common.deserialize_packets(buf[:read], payloads)
	}

	if net_err != nil && net_err != net.TCP_Recv_Error.Would_Block {
		log.errorf("Failed to read player command: %v", net_err)
		return net_err
	}

	return nil
}

send_state :: proc(client: Client, player: Player, state: common.State) -> net.Network_Error {
	my_turn: b8
	ready: b8
	#partial switch s in state {
	case common.PlayState:
		my_turn = s.player == player.pawn
	case common.WinState:
		ready = s.player_ready[player.client_index]
	}

	payload: common.ServerPayload = common.GameState {
		ready   = ready,
		my_turn = my_turn,
		state   = state,
	}
	return send(client.sock, payload)
}
