package common

import "core:net"
import "core:slice"

@(private = "file")
PROTOCOL_ID :: 1758937834

@(private = "file")
Packet :: struct {
	header:  Header,
	payload: Payload,
}

@(private = "file")
Header :: struct {
	protocol_id: u32,
}

@(private = "file")
DEFAULT_HEADER := Header {
	protocol_id = PROTOCOL_ID,
}

Payload :: union #no_nil {
	ServerPayload,
	ClientPayload,
}

ServerPayload :: union #no_nil {
	ConnectAck,
	State,
}

ConnectAck :: struct {
	pawn:  Pawn,
	state: State,
}

ClientPayload :: struct {
	type: ClientPayloadType,
	pawn: Pawn,
}

ClientPayloadType :: union #no_nil {
	Move,
	Restart,
	Disconnect,
}

Disconnect :: struct {}

Move :: struct {
	turn, x, y: u8,
}

Restart :: struct {}


Error :: enum {
	None,
	WrongProtocolId,
}

send :: proc(socket: net.TCP_Socket, payload: Payload) -> net.Network_Error {
	buf: [size_of(Packet)]byte
	size := serialize_packet(payload, buf[:])
	net.send(socket, buf[:size]) or_return
	return nil
}

serialize_packet :: proc(payload: Payload, buf: []byte) -> int {
	assert(len(buf) >= size_of(Packet), "buffer not big enough to contain packet")

	packet := Packet {
		header  = DEFAULT_HEADER,
		payload = payload,
	}
	as_bytes := transmute([size_of(Packet)]byte)packet

	return copy(buf, as_bytes[:])
}

deserialize_packet :: proc(buf: []byte) -> (p: Payload, err: Error) {
	assert(len(buf) >= size_of(Packet), "buffer not big enough to contain packet")

	packet, _ := slice.to_type(buf, Packet)
	if packet.header.protocol_id != PROTOCOL_ID {
		err = .WrongProtocolId
		return
	}

	p = packet.payload
	return
}

deserialize_packets :: proc(buf: []byte, payloads: ^[dynamic]Payload) -> (count: int) {
	packets := slice.reinterpret([]Packet, buf)
	for p in packets {
		if p.header.protocol_id == PROTOCOL_ID {
			append(payloads, p.payload)
			count += 1
		}
	}
	return
}
