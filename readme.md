# Tic Tac Toc written in [Odin](https://odin-lang.org/)

First simple project to discover the language and raylib.

This is a simple network tictactoe game. It uses TCP sockets.

## How to play 

- Click on the board or move with ⬆️⬇️⬅️➡️ and press Enter to place a pawn 
- The goal is to align 3 pawns of the same type
- Click the header or press Enter to restart !

## How to run 

### the server

```sh
# to start on any available port
odin run ./server/

# or
odin run ./server/ -- -port=<port>
```

### the client

Build it then start the executable twice

```sh
odin build ./client/
```
