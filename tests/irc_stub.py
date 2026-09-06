#!/usr/bin/env python3
import socket
import sys
import time

HOST = "127.0.0.1"
PORT = 16667
TIMEOUT = 20


def send(conn, line):
    conn.sendall((line + "\r\n").encode())


def main():
    deadline = time.time() + TIMEOUT
    nick = None
    user_seen = False
    joined = False
    pong = False

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((HOST, PORT))
        server.listen(1)
        server.settimeout(TIMEOUT)
        print(f"LISTEN {HOST}:{PORT}", flush=True)
        conn, _ = server.accept()
        with conn:
            conn.settimeout(1)
            buf = b""
            registered = False
            while time.time() < deadline:
                try:
                    chunk = conn.recv(4096)
                except socket.timeout:
                    continue
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    raw, buf = buf.split(b"\n", 1)
                    line = raw.rstrip(b"\r").decode(errors="replace")
                    print(f"C {line}", flush=True)
                    upper = line.upper()
                    if upper.startswith("NICK "):
                        nick = line.split(" ", 1)[1].lstrip(":")
                    elif upper.startswith("USER "):
                        user_seen = True

                    if nick and user_seen and not registered:
                        registered = True
                        print("REGISTERED", flush=True)
                        send(conn, f":irc.test 001 {nick} :Welcome to the M1.3 test IRC server")
                        send(conn, f":irc.test 002 {nick} :Your host is irc.test")
                        send(conn, f":irc.test 003 {nick} :This server was created for CI")
                        send(conn, f":irc.test 004 {nick} irc.test 0.1 o o")
                        send(conn, f":irc.test 005 {nick} CHANTYPES=# PREFIX=(ov)@+ :are supported")
                        send(conn, f":irc.test 375 {nick} :- irc.test Message of the Day -")
                        send(conn, f":irc.test 372 {nick} :- M1.3 integration test")
                        send(conn, f":irc.test 376 {nick} :End of MOTD")

                    if upper.startswith("JOIN ") and "#CI" in upper:
                        joined = True
                        print("JOINED #ci", flush=True)
                        send(conn, f":{nick}!limnoria@localhost JOIN #ci")
                        send(conn, f":irc.test 353 {nick} = #ci :@{nick}")
                        send(conn, f":irc.test 366 {nick} #ci :End of NAMES list")
                        send(conn, "PING :m1.3")
                    elif upper.startswith("PONG") and "M1.3" in upper:
                        pong = True
                        print("PONG_OK", flush=True)
                        return 0 if joined else 2

    if not nick or not user_seen:
        print("registration incomplete", file=sys.stderr)
    elif not joined:
        print("bot did not join #ci", file=sys.stderr)
    elif not pong:
        print("bot did not answer PING", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
