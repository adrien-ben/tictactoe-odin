package client

import "core:log"
import "core:net"

import "../common"

connect :: proc(
	address: net.Address,
	port: int,
) -> (
	sock: net.TCP_Socket,
	ack: common.ConnectAck,
	err: net.Network_Error,
) {
	log.info("Connecting to server...")
	endpoint := net.Endpoint {
		address = address,
		port    = port,
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

	if err == net.TCP_Recv_Error.Would_Block {
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
		if err != nil && err != net.TCP_Recv_Error.Would_Block {
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
