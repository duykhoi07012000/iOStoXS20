"""PTP client cho Fuji X-S20 qua Wi-Fi — GIẢI MÃ TỪ CAPTURE THẬT.

Khác PTP/IP chuẩn (đã xác nhận bằng Wireshark, xem docs/protocol-notes.md):
- Cổng **15740**, MỘT kết nối TCP, KHÔNG event channel, KHÔNG UDP discovery.
- Handshake dùng header 8 byte kiểu PTP/IP: [len u32][type u32].
- Sau handshake chuyển sang container kiểu PTP-USB, header 12 byte:
  [len u32][type u16][code u16][transactionID u32][payload]
  type: 1=Command, 2=Data, 3=Response, 4=Event. respcode OK = 0x2001.

Cách dùng:
    with FujiCamera("192.168.1.50") as cam:
        cam.set_prop(0xD001, 0x000B, "u16")   # Film Simulation = Classic Chrome
"""

from __future__ import annotations

import socket
import struct
import time
import uuid
from contextlib import AbstractContextManager

DEFAULT_IP = "192.168.1.50"
DEFAULT_PORT = 15740        # cổng PTP; thực tế lấy từ DSCPORT trong bước discovery
CLIENT_NAME = "iOStoXS20"

# Giao thức discovery "PCSS/1.0" (giải mã từ capture) — BẮT BUỘC, nếu không máy
# sẽ KHÔNG mở cổng PTP (nối thẳng bị refused).
PCSS_CAMERA_UDP_PORT = 51562   # máy nghe gói DISCOVERY (UDP) ở cổng này
PCSS_PC_TCP_PORT = 51560       # PC phải nghe NOTIFY (TCP) ở cổng này

# PTP/IP init packet types (header 8 byte)
INIT_COMMAND_REQUEST = 0x00000001
INIT_COMMAND_ACK = 0x00000002
INIT_FAIL = 0x00000005

# PTP-USB container types (header 12 byte)
CT_COMMAND = 1
CT_DATA = 2
CT_RESPONSE = 3
CT_EVENT = 4

# Operation codes
OP_GET_DEVICE_INFO = 0x1001
OP_OPEN_SESSION = 0x1002
OP_CLOSE_SESSION = 0x1003
OP_GET_DEVICE_PROP_VALUE = 0x1015
OP_SET_DEVICE_PROP_VALUE = 0x1016

RC_OK = 0x2001

_DT = {"u8": "<B", "i8": "<b", "u16": "<H", "i16": "<h",
       "u32": "<I", "i32": "<i", "u64": "<Q"}


class FujiError(RuntimeError):
    pass


def _utf16z(s: str) -> bytes:
    return s.encode("utf-16-le") + b"\x00\x00"


def discover(camera_ip: str, timeout: float = 8.0, retries: int = 3) -> tuple[str, int]:
    """Bước discovery PCSS/1.0. Trả (dsc_ip, dsc_port) để nối PTP sau đó.

    Trình tự (từ capture thật):
      1. PC mở TCP listener ở cổng 51560.
      2. PC gửi UDP "DISCOVERY * HTTP/1.1" tới camera:51562 (kèm HOST = IP của PC).
      3. Camera nối ngược lại PC:51560, gửi "NOTIFY ..." có DSC + DSCPORT.
      4. PC trả "HTTP/1.1 200 OK".
    """
    # xác định IP LAN của PC (route tới camera)
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect((camera_ip, PCSS_CAMERA_UDP_PORT))
        local_ip = probe.getsockname()[0]
    finally:
        probe.close()

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        srv.bind(("0.0.0.0", PCSS_PC_TCP_PORT))
    except OSError as e:
        raise FujiError(
            f"Không bind được TCP {PCSS_PC_TCP_PORT} (cổng nhận NOTIFY): {e}. "
            "Đóng phần mềm tether khác đang chiếm cổng."
        ) from e
    srv.listen(1)
    srv.settimeout(timeout)

    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    disc = (f"DISCOVERY * HTTP/1.1\r\nHOST: {local_ip}\r\n"
            f"MX: 5\r\nSERVICE: PCSS/1.0\r\n\x00").encode("ascii")
    try:
        last_err: Exception | None = None
        for _ in range(retries):
            udp.sendto(disc, (camera_ip, PCSS_CAMERA_UDP_PORT))
            try:
                conn, _addr = srv.accept()
            except socket.timeout as e:
                last_err = e
                continue
            with conn:
                notify = conn.recv(2048).decode("ascii", errors="replace")
                dsc_ip, dsc_port = camera_ip, DEFAULT_PORT
                for line in notify.split("\r\n"):
                    k, _, v = line.partition(":")
                    if k.strip().upper() == "DSCPORT" and v.strip().isdigit():
                        dsc_port = int(v.strip())
                    elif k.strip().upper() == "DSC" and v.strip():
                        dsc_ip = v.strip()
                conn.sendall(b"HTTP/1.1 200 OK\r\n")
                return dsc_ip, dsc_port
        raise FujiError(
            "Discovery thất bại: máy không gửi NOTIFY. Kiểm tra: máy ở WIRELESS "
            "TETHER SHOOTING FIXED (đèn cam chớp), đúng IP, và Windows Firewall "
            f"cho phép nhận kết nối vào cổng {PCSS_PC_TCP_PORT}."
        ) from last_err
    finally:
        udp.close()
        srv.close()


class FujiCamera(AbstractContextManager):
    def __init__(self, ip: str = DEFAULT_IP, port: int = DEFAULT_PORT,
                 client_name: str = CLIENT_NAME, timeout: float = 10.0,
                 use_discovery: bool = True, client_guid: bytes | None = None):
        self.ip = ip
        self.port = port
        self.use_discovery = use_discovery
        self.client_name = client_name
        self.client_guid = client_guid or uuid.uuid4().bytes
        self.connection_number = 0
        self.transaction_id = 0
        self._sock: socket.socket | None = None

    # ---- context manager ----
    def __enter__(self) -> "FujiCamera":
        self.connect()
        return self

    def __exit__(self, *exc) -> None:
        self.close()

    # ---- khung gói mức thấp ----
    def _send_raw(self, body: bytes) -> None:
        assert self._sock is not None
        self._sock.sendall(struct.pack("<I", 4 + len(body)) + body)

    def _recv_raw(self) -> bytes:
        length = struct.unpack("<I", self._recv_exact(4))[0]
        if length < 4:
            raise FujiError(f"Container length bất thường: {length}")
        return self._recv_exact(length - 4)

    def _recv_exact(self, n: int) -> bytes:
        assert self._sock is not None
        buf = bytearray()
        while len(buf) < n:
            chunk = self._sock.recv(n - len(buf))
            if not chunk:
                raise FujiError("Kết nối đóng giữa chừng")
            buf += chunk
        return bytes(buf)

    # ---- handshake ----
    def connect(self) -> None:
        ip, port = self.ip, self.port
        if self.use_discovery:
            ip, port = discover(self.ip)   # PCSS/1.0 — bắt buộc để máy mở cổng PTP

        # IP LAN của PC (đưa vào InitCommandRequest, đảo octet như capture)
        probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            probe.connect((ip, port))
            local_ip = probe.getsockname()[0]
        finally:
            probe.close()
        client_ip_field = bytes(reversed(socket.inet_aton(local_ip)))

        self._sock = socket.create_connection((ip, port), timeout=10.0)
        self._sock.settimeout(10.0)

        # InitCommandRequest (định dạng Fuji giải mã từ capture):
        # [type u32=1][GUID 16][clientIP 4][vùng tên cố định 54B = name UTF16Z + đệm 0]
        # Tổng body = 78 byte. THIẾU đệm này → máy từ chối 0x201D.
        name_region = _utf16z(self.client_name).ljust(54, b"\x00")[:54]
        body = (struct.pack("<I", INIT_COMMAND_REQUEST) + self.client_guid
                + client_ip_field + name_region)

        # Máy thường InitFail lần đầu (0x2019 = busy) rồi Ack ở lần retry.
        try:
            last_fail = None
            for attempt in range(5):
                self._send_raw(body)
                resp = self._recv_raw()
                ptype = struct.unpack_from("<I", resp, 0)[0]
                if ptype == INIT_COMMAND_ACK:
                    self.connection_number = struct.unpack_from("<I", resp, 4)[0]
                    break
                if ptype == INIT_FAIL:
                    last_fail = struct.unpack_from("<I", resp, 4)[0]
                    time.sleep(0.6)
                    continue
            else:
                raise FujiError(
                    f"InitCommandAck không tới (InitFail reason 0x{last_fail:04X}). "
                    "Nếu 0x201D lặp lại: máy bận do kết nối cũ treo — TẮT/BẬT máy "
                    "(hoặc vào lại WIRELESS TETHER SHOOTING FIXED) rồi thử lại.")
            self.open_session()
        except BaseException:
            self.close()        # tránh để socket 15740 treo → máy báo busy lần sau
            raise

    # ---- PTP operations (container PTP-USB) ----
    def _next_tid(self) -> int:
        self.transaction_id += 1
        return self.transaction_id

    def _send_container(self, ctype: int, code: int, tid: int, payload: bytes = b"") -> None:
        self._send_raw(struct.pack("<HHI", ctype, code, tid) + payload)

    def _transact(self, opcode: int, params: list[int] | None = None,
                  data_out: bytes | None = None) -> tuple[int, bytes]:
        """Gửi 1 operation, trả (response_code, data_in)."""
        tid = self._next_tid()
        pbytes = b"".join(struct.pack("<I", p & 0xFFFFFFFF) for p in (params or []))
        self._send_container(CT_COMMAND, opcode, tid, pbytes)
        if data_out is not None:
            self._send_container(CT_DATA, opcode, tid, data_out)

        data_in = bytearray()
        for _ in range(50):
            body = self._recv_raw()
            ctype, code = struct.unpack_from("<HH", body, 0)
            payload = body[8:]
            if ctype == CT_RESPONSE:
                return code, bytes(data_in)
            if ctype == CT_DATA:
                data_in += payload
            # CT_EVENT (4) hoặc khác: bỏ qua
        raise FujiError("Không nhận được Response sau 50 gói")

    def open_session(self, session_id: int = 1) -> None:
        rc, _ = self._transact(OP_OPEN_SESSION, [session_id])
        # Một số firmware trả 0x201E (SessionAlreadyOpen) nếu mở lại — chấp nhận.
        if rc not in (RC_OK, 0x201E):
            raise FujiError(f"OpenSession lỗi rc=0x{rc:04X}")

    def get_prop(self, prop_code: int) -> bytes:
        rc, data = self._transact(OP_GET_DEVICE_PROP_VALUE, [prop_code])
        if rc != RC_OK:
            raise FujiError(f"GetProp 0x{prop_code:04X} lỗi rc=0x{rc:04X}")
        return data

    def set_prop(self, prop_code: int, value: int, datatype: str) -> int:
        """SetDevicePropValue. Trả response code (0x2001 = OK)."""
        data = struct.pack(_DT[datatype], value)
        rc, _ = self._transact(OP_SET_DEVICE_PROP_VALUE, [prop_code], data_out=data)
        return rc

    def close_session(self) -> None:
        if self._sock is None:
            return
        try:
            self._transact(OP_CLOSE_SESSION)
        except (OSError, FujiError):
            pass

    def close(self) -> None:
        self.close_session()
        if self._sock:
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None
