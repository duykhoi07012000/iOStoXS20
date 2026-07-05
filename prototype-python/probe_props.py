"""Dò property code của X-S20 qua PTP/IP — chạy TRÊN PC (cùng Wi-Fi với máy ảnh).

Mục đích: tìm property code của MIỀN VIDEO (áp recipe ở Movie mode bị máy từ chối vì
video dùng code riêng, chưa biết). Port trung thực phần kết nối từ FujiKit (PCSSDiscovery,
PTPCodec, FujiCamera). Xem docs/protocol-notes.md.

Dùng:
  # 1) Để máy ở STILLS mode, chạy:
  python probe_props.py snapshot stills.json --ip 192.168.1.50
  # 2) Vặn máy sang MOVIE mode, chạy:
  python probe_props.py snapshot movie.json  --ip 192.168.1.50
  # 3) Gửi 2 file đó cho tôi. (Hoặc tự so:)
  python probe_props.py diff stills.json movie.json

Lưu ý:
  - PC + máy ảnh phải CÙNG router; máy ở WIRELESS TETHER SHOOTING FIXED (đèn cam chớp).
  - ĐÓNG app trên điện thoại trước (máy chỉ cho 1 kết nối một lúc).
  - Windows Firewall phải cho Python mở cổng TCP 51560 (bấm Allow khi hỏi).
  - --ip là IP máy ảnh (xem trong NETWORK SETTING của máy). Bỏ --ip = thử broadcast.
"""
from __future__ import annotations

import json
import socket
import struct
import sys
import time

GUID = bytes.fromhex("f2e4538fada5485d87b27f0bd3d5ded0")  # GUID đã pair (giống app)
NAME = "DESKTOP-SGP1R6M"
UDP_CAM_PORT = 51562
TCP_LISTEN_PORT = 51560
OP_OPEN_SESSION = 0x1002
OP_GET_PROP_DESC = 0x1014
RC_OK = 0x2001

# Dải code quét (vendor Fuji + vài code PTP chuẩn hay dùng).
CANDIDATES = list(range(0xD000, 0xD400)) + list(range(0x5000, 0x5020))

# Kích thước (byte) theo DataType PTP.
DT_SIZE = {0x0001: 1, 0x0002: 1, 0x0003: 2, 0x0004: 2, 0x0005: 4, 0x0006: 4, 0x0007: 8, 0x0008: 8}


def local_ip(cam_ip: str | None) -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect((cam_ip or "8.8.8.8", 9))
        return s.getsockname()[0]
    finally:
        s.close()


def pcss_discover(cam_ip: str | None, lip: str, timeout: float = 8.0):
    """Trả (dsc_ip, dsc_port). Mở TCP listener, gửi UDP DISCOVERY, chờ máy nối ngược."""
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", TCP_LISTEN_PORT))
    srv.listen(1)
    srv.settimeout(timeout)

    msg = f"DISCOVERY * HTTP/1.1\r\nHOST: {lip}\r\nMX: 5\r\nSERVICE: PCSS/1.0\r\n\x00".encode()
    u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    u.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    u.sendto(msg, (cam_ip or "255.255.255.255", UDP_CAM_PORT))
    u.close()

    try:
        conn, addr = srv.accept()
    except socket.timeout:
        srv.close()
        raise SystemExit("Het gio cho NOTIFY. May o tether standby? Firewall cong 51560? Sai --ip?")
    notify = conn.recv(2048).decode("ascii", "replace")
    dsc_ip, dsc_port = (cam_ip or addr[0]), 15740
    for line in notify.split("\r\n"):
        if ":" in line:
            k, v = line.split(":", 1)
            k, v = k.strip().upper(), v.strip()
            if k == "DSCPORT" and v.isdigit():
                dsc_port = int(v)
            elif k == "DSC" and v:
                dsc_ip = v
    conn.sendall(b"HTTP/1.1 200 OK\r\n")
    conn.close()
    srv.close()
    return dsc_ip, dsc_port


class Cam:
    def __init__(self, ip: str, port: int):
        self.sock = socket.create_connection((ip, port), timeout=10)
        self.tid = 0

    def _send_framed(self, payload: bytes):
        self.sock.sendall(struct.pack("<I", 4 + len(payload)) + payload)

    def _recvn(self, n: int) -> bytes:
        buf = b""
        while len(buf) < n:
            c = self.sock.recv(n - len(buf))
            if not c:
                raise IOError("ket noi dong giua chung")
            buf += c
        return buf

    def _read_packet(self) -> bytes:
        ln = struct.unpack("<I", self._recvn(4))[0]
        return self._recvn(ln - 4) if ln > 4 else b""

    def connect(self):
        name_region = (NAME.encode("utf-16-le") + b"\x00\x00")[:54].ljust(54, b"\x00")
        ip_field = bytes(reversed([int(x) for x in local_ip_for_init.split(".")]))
        init = struct.pack("<I", 1) + GUID[:16] + ip_field + name_region
        for _ in range(5):
            self._send_framed(init)
            resp = self._read_packet()
            typ = struct.unpack("<I", resp[:4])[0] if len(resp) >= 4 else 0
            if typ == 2:            # InitCommandAck
                break
            if typ == 5:            # InitFail (busy) → retry
                time.sleep(0.6)
        else:
            raise IOError("InitCommandRequest bi tu choi (GUID chua pair? may ban?)")
        rc, _ = self.transact(OP_OPEN_SESSION, [1])
        if rc not in (RC_OK, 0x201E):
            raise IOError(f"OpenSession rc=0x{rc:04X}")

    def transact(self, code: int, params=(), data_out: bytes | None = None):
        self.tid += 1
        t = self.tid
        pbytes = b"".join(struct.pack("<I", p) for p in params)
        self._send_framed(struct.pack("<HHI", 1, code, t) + pbytes)   # Command
        if data_out is not None:
            self._send_framed(struct.pack("<HHI", 2, code, t) + data_out)
        indata = b""
        for _ in range(60):
            body = self._read_packet()
            if len(body) < 8:
                continue
            ctype, _ccode, _ctid = struct.unpack("<HHI", body[:8])
            payload = body[8:]
            if ctype == 3:          # Response
                return _ccode, indata
            if ctype == 2:          # Data
                indata += payload
        raise IOError("khong nhan duoc Response")

    def prop_desc(self, code: int):
        rc, data = self.transact(OP_GET_PROP_DESC, [code])
        return data if rc == RC_OK and data else None

    def close(self):
        try:
            self.transact(0x1003)   # CloseSession
        except Exception:
            pass
        self.sock.close()


def parse_desc(d: bytes) -> dict:
    """Best-effort: code, datatype, getset, default, current + raw hex (giữ nguyên để phân tích)."""
    out = {"raw": d.hex()}
    if len(d) < 5:
        return out
    code, dtype, getset = struct.unpack("<HHB", d[:5])
    out.update(code=code, datatype=dtype, getset=getset)
    size = DT_SIZE.get(dtype)
    off = 5
    if size and len(d) >= off + 2 * size:
        out["default"] = d[off:off + size][::-1].hex()          # LE → hex đọc xuôi
        out["current"] = d[off + size:off + 2 * size][::-1].hex()
    return out


local_ip_for_init = "0.0.0.0"   # gán trong main()


def do_snapshot(path: str, cam_ip: str | None):
    global local_ip_for_init
    lip = local_ip(cam_ip)
    local_ip_for_init = lip
    print(f"PC IP={lip}. Discovery...")
    dsc_ip, dsc_port = pcss_discover(cam_ip, lip)
    print(f"May: {dsc_ip}:{dsc_port}. Handshake...")
    cam = Cam(dsc_ip, dsc_port)
    cam.connect()
    print(f"Ket noi OK. Quet {len(CANDIDATES)} code (bo qua code khong ho tro)...")
    props = {}
    for i, code in enumerate(CANDIDATES):
        try:
            d = cam.prop_desc(code)
        except Exception:
            d = None
        if d:
            props[f"0x{code:04X}"] = parse_desc(d)
        if (i + 1) % 128 == 0:
            print(f"  {i + 1}/{len(CANDIDATES)}  (da doc {len(props)} code)")
    cam.close()
    json.dump(props, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"XONG: {len(props)} property -> {path}")


def do_set(code: int, value: int, cam_ip: str | None, signed: bool):
    global local_ip_for_init
    lip = local_ip(cam_ip)
    local_ip_for_init = lip
    dsc_ip, dsc_port = pcss_discover(cam_ip, lip)
    cam = Cam(dsc_ip, dsc_port)
    cam.connect()
    data = struct.pack("<h" if signed else "<H", value)
    rc, _ = cam.transact(0x1016, [code], data)   # SetDevicePropValue
    cam.close()
    ok = "OK" if rc == RC_OK else "FAIL"
    print(f"SET 0x{code:04X} = {value}  ->  rc=0x{rc:04X}  [{ok}]")


def do_diff(a_path: str, b_path: str):
    a = json.load(open(a_path, encoding="utf-8"))
    b = json.load(open(b_path, encoding="utf-8"))
    print(f"{a_path}: {len(a)} code | {b_path}: {len(b)} code")
    only_b = [k for k in b if k not in a]
    if only_b:
        print(f"\nCHI CO trong {b_path} ({len(only_b)}): {only_b}")
    print("\nCODE co CURRENT khac nhau (nghi la thong so ban vua doi tay):")
    for k in sorted(set(a) & set(b)):
        ca, cb = a[k].get("current"), b[k].get("current")
        if ca != cb:
            print(f"  {k}: {ca}  ->  {cb}   (datatype={b[k].get('datatype')})")


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")   # cho in được tiếng Việt trên console Windows
    except Exception:
        pass
    args = sys.argv[1:]
    if len(args) >= 2 and args[0] == "snapshot":
        ip = None
        if "--ip" in args:
            ip = args[args.index("--ip") + 1]
        do_snapshot(args[1], ip)
    elif len(args) >= 3 and args[0] == "set":
        ip = args[args.index("--ip") + 1] if "--ip" in args else None
        signed = "--i16" in args
        do_set(int(args[1], 0), int(args[2], 0), ip, signed)
    elif len(args) == 3 and args[0] == "diff":
        do_diff(args[1], args[2])
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
