"""fuji_xs20 — client PTP/IP đẩy film recipe xuống Fujifilm X-S20 (Phase 1).

Giao thức đã giải mã từ capture thật: TCP port 15740, handshake PTP/IP rồi chuyển
sang container kiểu PTP-USB; property code dải vendor 0xDxxx (Film Sim = 0xD001).
"""

from .recipe import Recipe, PropertyWrite
from .ptpip import FujiCamera, FujiError

__all__ = ["Recipe", "PropertyWrite", "FujiCamera", "FujiError"]
__version__ = "0.2.0"
