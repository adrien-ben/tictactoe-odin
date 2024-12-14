package client

import "core:log"
import "core:net"
import "core:strconv"
import "core:strings"

import "../common"

TCP_RECV_WOULD_BLOCK_ERR ::
	net.TCP_Recv_Error.Would_Block when ODIN_OS == .Windows else net.TCP_Recv_Error.Timeout

ServerAddress :: struct {
	addr: [4]u8,
	port: u16,
}

parse_address :: proc(s: string) -> (addr: ServerAddress, ok: bool) {
	s := s
	i: int
	for addr_or_port in strings.split_iterator(&s, ":") {
		if i == 0 {
			j: int
			addr_or_port := addr_or_port
			for addr_part in strings.split_iterator(&addr_or_port, ".") {
				if j > 3 do return

				part := strconv.parse_uint(addr_part) or_return
				if part > uint(max(u8)) do return

				addr.addr[j] = u8(part)
				j += 1
			}

			if j < 4 do return
		} else if i == 1 {
			port := strconv.parse_uint(addr_or_port) or_return
			if port > uint(max(u16)) do return
			addr.port = u16(port)
			ok = true
			return
		} else {
			ok = false
			return
		}

		i += 1
	}

	return
}

connect :: proc(
	addr: ServerAddress,
) -> (
	sock: net.TCP_Socket,
	ack: common.ConnectAck,
	err: net.Network_Error,
) {
	log.info("Connecting to server...")
	endpoint := net.Endpoint {
		address = net.IP4_Address{addr.addr[0], addr.addr[1], addr.addr[2], addr.addr[3]},
		port    = int(addr.port),
	}
	sock, err = net.dial_tcp_from_endpoint(endpoint)
	if err != nil {
		log.errorf("Failed to dial server: %v.", err)
		return
	}
	err = net.set_blocking(sock, false)
	if err != nil {
		log.errorf("Failed to set socket to non blocking: %v.", err)
		return
	}

	payloads: [dynamic]common.Payload
	defer delete(payloads)

	ack_count, ack_err := recv(sock, &payloads)
	log.assertf(
		ack_count == 1 && ack_err == nil,
		"Failed to get player id from server. Ack count: %v. Err: %v.",
		ack_count,
		ack_err,
	)

	payload := pop_front(&payloads)
	init_payload, is_server_payload := payload.(common.ServerPayload)
	log.assertf(is_server_payload, "Received data is not initialization payload.")

	is_ack: bool
	ack, is_ack = init_payload.(common.ConnectAck)
	log.assertf(is_ack, "Received data is not initialization payload.")

	return
}

send :: proc(socket: net.TCP_Socket, payload: common.ClientPayload) -> net.Network_Error {
	return common.send(socket, payload)
}

try_recv :: proc(
	socket: net.TCP_Socket,
	payloads: ^[dynamic]common.Payload,
) -> (
	count: int,
	err: net.Network_Error,
) {
	buf: [1024]byte
	read: int
	for read, err = net.recv(socket, buf[:]);
	    read > 0 && err == nil;
	    read, err = net.recv(socket, buf[:]) {

		count = common.deserialize_packets(buf[:read], payloads)
	}

	if err == TCP_RECV_WOULD_BLOCK_ERR {
		err = nil
	}

	return
}

recv :: proc(
	socket: net.TCP_Socket,
	payloads: ^[dynamic]common.Payload,
) -> (
	count: int,
	err: net.Network_Error,
) {
	buf: [1024]byte
	recieved: bool
	for {
		read, read_err := net.recv(socket, buf[:])

		// error while reading
		if err != nil && err != TCP_RECV_WOULD_BLOCK_ERR {
			err = read_err
			return
		}

		// we read everything
		if read == 0 && recieved {
			return
		}

		// we reveived some content
		if read > 0 {
			recieved = true
			count += common.deserialize_packets(buf[:read], payloads)
		}
	}
}
