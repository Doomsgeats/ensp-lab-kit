# -*- coding: utf-8 -*-
"""Minimal telnet client for Huawei eNSP device consoles.

eNSP opens every device's console on 127.0.0.1:<com_port> and speaks telnet with
option negotiation. A plain socket will get stuck on IAC sequences, so this module
answers them (refusing every option - that is all a console needs) and gives you
send/run helpers.

Example:
    from vrp_console import VrpConsole

    sw = VrpConsole(2001)            # SD
    sw.login()                       # wait for <Huawei> / <SD>
    sw.run(["system-view",
            "sysname SD",
            "vlan batch 10 40",
            "interface Vlanif10", "ip address 192.168.1.1 24", "quit",
            "quit"])
    sw.run(["save"], answers=["y", ""])   # filename prompt: confirm, then Enter
    sw.close()

Gotchas encoded here (each one cost a debugging session):
  * After a device reboot the console needs one or two Enter presses before it
    answers; that is why login() sends empty lines first.
  * `save` asks for a filename (default vrpcfg.zip) - press Enter, not `y`.
  * A leftover `[Y/N]` prompt swallows every following command and makes VRP
    answer "Unrecognized command found at '^' position" at a random place.
"""
import re
import socket
import time

IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


class VrpConsole:
    def __init__(self, port, host="127.0.0.1", timeout=10, settle=1.0):
        self.port = int(port)
        self.sock = socket.create_connection((host, self.port), timeout=timeout)
        self.banner = self._read(settle)
        self.log = [self.banner]

    # -- low level -------------------------------------------------------
    def _drain(self, wait):
        self.sock.settimeout(wait)
        buf = b""
        while True:
            try:
                chunk = self.sock.recv(65535)
                if not chunk:
                    break
                buf += chunk
            except (socket.timeout, OSError):
                break
        return buf

    def _strip_iac(self, data):
        out = bytearray()
        i = 0
        while i < len(data):
            byte = data[i]
            if byte != IAC:
                out.append(byte)
                i += 1
                continue
            if i + 1 >= len(data):
                break
            cmd = data[i + 1]
            if cmd in (DO, DONT, WILL, WONT):
                opt = data[i + 2] if i + 2 < len(data) else 0
                reply = bytes([IAC, WONT if cmd == DO else DONT, opt])
                try:
                    self.sock.sendall(reply)
                except OSError:
                    pass
                i += 3
                continue
            if cmd == SB:  # subnegotiation: skip to IAC SE
                end = data.find(bytes([IAC, SE]), i)
                i = end + 2 if end >= 0 else len(data)
                continue
            i += 2
        return bytes(out)

    def _read(self, wait=0.3):
        return self._strip_iac(self._drain(wait)).decode("utf-8", "ignore")

    # -- public ----------------------------------------------------------
    def send(self, line, wait=0.35):
        self.sock.sendall(line.encode() + b"\r\n")
        time.sleep(wait)
        text = ANSI.sub("", self._read(0.15))
        self.log.append(text)
        return text

    def login(self, tries=3):
        """Press Enter until the prompt shows up (needed right after boot)."""
        for _ in range(tries):
            text = self.send("", 0.8)
            if self.prompt(text) or "<" in text or ">" in text:
                return text
        return text

    @staticmethod
    def prompt(text):
        match = re.findall(r"^\s*[<\[][\w\-]+[>\]]\s*$", text, re.M)
        return match[-1].strip() if match else ""

    def run(self, commands, answers=None, wait=0.42):
        """Send commands in order. `answers` are fed to consecutive Y/N prompts."""
        replies = []
        pending = list(answers or [])
        for cmd in commands:
            out = self.send(cmd, wait)
            replies.append(out)
            while pending and re.search(r"\[Y/N\]|\(y/n\)|\[Y/N\]:", out, re.I):
                out = self.send(pending.pop(0), 0.6)
                replies.append(out)
        return "\n".join(replies)

    def errors(self, text=None):
        body = text if text is not None else "\n".join(self.log)
        return [line for line in body.splitlines() if re.search(r"Error|Unrecognized|Too many parameters", line, re.I)]

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


if __name__ == "__main__":
    import sys

    port = int(sys.argv[1]) if len(sys.argv) > 1 else 2001
    con = VrpConsole(port)
    con.login()
    print(con.run(["display version"], wait=1.2))
    con.close()