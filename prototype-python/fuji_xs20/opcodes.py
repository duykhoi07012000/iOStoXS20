"""X-S20 PTP property codes + value enums.

Trích trực tiếp từ FUJIFILM Camera Remote SDK 1.34
(SDK13410/SDK13410/HEADERS/XAPIOpt.H, X-S20.h). Xem docs/xs20-recipe-reference.md.

⚠️ Giả thuyết: PTP device-property-code == API_CODE của SDK. Phải xác nhận lại
bằng capture Wireshark ở Phase 0. Nếu sai, chỉ cần sửa bảng PROP_CODE bên dưới —
toàn bộ code khác giữ nguyên.
"""

from enum import IntEnum

# --- PTP/IP standard operation codes ---------------------------------------
PTP_OP_GET_DEVICE_INFO = 0x1001
PTP_OP_OPEN_SESSION = 0x1002
PTP_OP_CLOSE_SESSION = 0x1003
PTP_OP_GET_DEVICE_PROP_DESC = 0x1014
PTP_OP_GET_DEVICE_PROP_VALUE = 0x1015
PTP_OP_SET_DEVICE_PROP_VALUE = 0x1016

# PTP/IP packet (container) types
PTPIP_INIT_COMMAND_REQUEST = 0x0001
PTPIP_INIT_COMMAND_ACK = 0x0002
PTPIP_INIT_EVENT_REQUEST = 0x0003
PTPIP_INIT_EVENT_ACK = 0x0004
PTPIP_INIT_FAIL = 0x0005
PTPIP_CMD_REQUEST = 0x0006   # Operation Request
PTPIP_CMD_RESPONSE = 0x0007  # Operation Response
PTPIP_EVENT = 0x0008
PTPIP_START_DATA = 0x0009
PTPIP_DATA = 0x000A
PTPIP_CANCEL = 0x000B
PTPIP_END_DATA = 0x000C
PTPIP_PING = 0x000D
PTPIP_PONG = 0x000E

PTP_RC_OK = 0x2001


# --- Device property codes cho từng trường recipe (== API_CODE SDK) ---------
# Đây là điểm DUY NHẤT cần chỉnh nếu capture cho thấy property code khác.
class Prop(IntEnum):
    FILM_SIMULATION = 0x2121
    GRAIN_EFFECT = 0x2152
    COLOR_CHROME_BLUE = 0x2168
    COLOR_CHROME_EFFECT = 0x2154  # giả thuyết = "Shadowing"; xác nhận Phase 0
    MONOCHROMATIC_COLOR = 0x216A
    CLARITY = 0x216C
    HIGHLIGHT_TONE = 0x2141
    SHADOW_TONE = 0x2143
    COLOR = 0x2105
    SHARPNESS = 0x2103
    NOISE_REDUCTION = 0x2131
    WIDE_DYNAMIC_RANGE = 0x2156
    WHITE_BALANCE_MODE = 0x2301
    WHITE_BALANCE_TUNE = 0x2304
    COLOR_SPACE = 0x2127


# --- Value enums (từ SDK_* defines) -----------------------------------------
class FilmSimulation(IntEnum):
    PROVIA = 1
    VELVIA = 2
    ASTIA = 3
    PRO_NEG_HI = 4
    PRO_NEG_STD = 5
    MONOCHROME = 6
    MONOCHROME_Ye = 7
    MONOCHROME_R = 8
    MONOCHROME_G = 9
    SEPIA = 10
    CLASSIC_CHROME = 11
    ACROS = 0x0C
    ACROS_Ye = 0x0D
    ACROS_R = 0x0E
    ACROS_G = 0x0F
    ETERNA = 0x10
    CLASSIC_NEG = 0x11
    ETERNA_BLEACH_BYPASS = 0x12
    NOSTALGIC_NEG = 0x13
    REALA_ACE = 0x14
    AUTO = 0x8000


class GrainEffect(IntEnum):
    OFF = 0x01
    WEAK_SMALL = 0x02
    STRONG_SMALL = 0x03
    WEAK_LARGE = 0x04
    STRONG_LARGE = 0x05
    OFF_LARGE = 0x07


class ColorChrome(IntEnum):  # dùng chung cho Blue & Effect
    OFF = 0x01
    WEAK = 0x02
    STRONG = 0x03


class NoiseReduction(IntEnum):
    P4 = 0x5000  # Extra High
    P3 = 0x6000  # Super High
    P2 = 0x0000  # High
    P1 = 0x1000  # Medium High
    STD = 0x2000  # 0
    M1 = 0x3000  # Medium Low
    M2 = 0x4000  # Low
    M3 = 0x7000  # Super Low
    M4 = 0x8000  # Extra Low


class DynamicRange(IntEnum):
    AUTO = 0xFFFF
    DR100 = 100
    DR200 = 200
    DR400 = 400
    DR800 = 800


class WhiteBalance(IntEnum):
    AUTO = 0x0002
    AUTO_WHITE_PRIORITY = 0x8020
    AUTO_AMBIENCE_PRIORITY = 0x8021
    DAYLIGHT = 0x0004
    INCANDESCENT = 0x0006
    UNDERWATER = 0x0008
    FLUORESCENT1 = 0x8001
    FLUORESCENT2 = 0x8002
    FLUORESCENT3 = 0x8003
    SHADE = 0x8006
    COLOR_TEMP = 0x8007
    CUSTOM1 = 0x8008
    CUSTOM2 = 0x8009
    CUSTOM3 = 0x800A
    CUSTOM4 = 0x800B
    CUSTOM5 = 0x800C


class ColorSpace(IntEnum):
    sRGB = 0x0001
    AdobeRGB = 0x0002


# --- Wire property codes THẬT (Fuji vendor 0xDxxx) — từ capture Wireshark -----
# CHỈ những mã != None mới được gửi xuống máy. None = chưa xác nhận, cần đối chiếu
# capture thêm (xem docs/protocol-notes.md). Giá trị wire của Film Sim == enum SDK.
# Xác nhận từ live GetDevicePropDesc trên X-S20 (khớp chữ ký giá trị với SDK).
WIRE_PROP: dict[str, int | None] = {
    "film_simulation": 0xD001,      # enum 1..0x14 (u16)
    "noise_reduction": 0xD01C,      # enum 0x0..0x8000 (u16)
    "dynamic_range": 0xD007,        # enum [0xffff,100,200,400] (u16) — X-S20 max 400
    "white_balance": 0x5005,        # enum WB (u16, standard PTP)
    "wb_kelvin": 0xD017,            # số Kelvin khi WB=ColorTemp (u16) — xác nhận trên máy
    "wb_shift_red": 0xD00B,         # range -9..9 (i16)
    "wb_shift_blue": 0xD00C,        # range -9..9 (i16)
    "highlight_tone": 0xD320,       # range -20..40 step 5 (i16, = -2.0..+4.0)
    "shadow_tone": 0xD321,          # range -20..40 step 5 (i16)
    "color": 0xD008,                # range -40..40 step 10 (i16)
    "sharpness": 0x5015,            # range -40..40 step 10 (i16, standard PTP)
    "clarity": 0xD032,              # range -50..50 step 10 (i16)
    "grain": 0xD023,                # enum 1..5,7 (off/weak/strong × small/large)
    "color_chrome_effect": 0xD029,  # enum 1/2/3 (off/weak/strong) — xác nhận diff
    "color_chrome_blue": 0xD030,    # enum 1/2/3 (off/weak/strong) — xác nhận diff
    # ⏳ còn lại (niche):
    "color_space": None,
    "mono_color": None,             # chỉ hiện khi film sim = monochrome/ACROS
}


# --- Dải giá trị cho các trường "×10" (giá trị truyền = hiển thị × 10) -------
# (min, max) theo đơn vị hiển thị ×10
TONE_RANGE = (-20, 40)       # Highlight/Shadow: -2.0..+4.0
COLOR_RANGE = (-40, 40)      # -4..+4
SHARPNESS_RANGE = (-40, 40)  # X-S20: -4..+4 (từ live desc)
CLARITY_RANGE = (-50, 50)    # -5..+5
WB_SHIFT_RANGE = (-9, 9)     # Red / Blue
MONO_COLOR_RANGE = (-180, 180)
