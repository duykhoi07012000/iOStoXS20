"""Recipe model + chuyển thành chuỗi PTP SetDevicePropValue (theo wire code thật).

Mỗi PropertyWrite mang theo `field` (tên trường) và `code` (property code wire,
tra từ opcodes.WIRE_PROP). Trường nào CHƯA có wire code (code=None) sẽ được tách ra
và KHÔNG gửi xuống máy — tránh ghi sai. Hiện chỉ Film Simulation đã xác nhận.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, fields
from pathlib import Path
from typing import Optional

from . import opcodes as oc


@dataclass
class PropertyWrite:
    field: str
    code: Optional[int]   # wire property code (None = chưa map)
    value: int
    datatype: str
    label: str = ""


def _clamp(name: str, v: int, rng: tuple[int, int]) -> int:
    lo, hi = rng
    if not (lo <= v <= hi):
        raise ValueError(f"{name}={v} ngoài dải hợp lệ {rng}")
    return v


@dataclass
class Recipe:
    name: str = "Untitled"

    film_simulation: Optional[oc.FilmSimulation] = None
    grain: Optional[oc.GrainEffect] = None
    color_chrome_blue: Optional[oc.ColorChrome] = None
    color_chrome_effect: Optional[oc.ColorChrome] = None
    noise_reduction: Optional[oc.NoiseReduction] = None
    dynamic_range: Optional[oc.DynamicRange] = None
    white_balance: Optional[oc.WhiteBalance] = None
    color_space: Optional[oc.ColorSpace] = None

    highlight_tone: Optional[float] = None
    shadow_tone: Optional[float] = None
    color: Optional[int] = None
    sharpness: Optional[int] = None
    clarity: Optional[int] = None
    wb_shift_red: Optional[int] = None
    wb_shift_blue: Optional[int] = None
    mono_warm_cool: Optional[int] = None
    mono_red_green: Optional[int] = None

    # ---- I/O ----
    @classmethod
    def from_json(cls, path: str | Path) -> "Recipe":
        return cls.from_dict(json.loads(Path(path).read_text(encoding="utf-8")))

    @classmethod
    def from_dict(cls, data: dict) -> "Recipe":
        kwargs: dict = {}
        valid = {f.name for f in fields(cls)}
        enum_map = {
            "film_simulation": oc.FilmSimulation, "grain": oc.GrainEffect,
            "color_chrome_blue": oc.ColorChrome, "color_chrome_effect": oc.ColorChrome,
            "noise_reduction": oc.NoiseReduction, "dynamic_range": oc.DynamicRange,
            "white_balance": oc.WhiteBalance, "color_space": oc.ColorSpace,
        }
        for k, v in data.items():
            if k not in valid:
                raise ValueError(f"Trường không hợp lệ trong recipe: {k!r}")
            if v is None:
                continue
            kwargs[k] = enum_map[k][v] if (k in enum_map and isinstance(v, str)) else v
        return cls(**kwargs)

    # ---- Build danh sách lệnh ghi ----
    def to_property_writes(self) -> list[PropertyWrite]:
        w: list[PropertyWrite] = []

        def add(field: str, value: int, dt: str, label: str):
            w.append(PropertyWrite(field, oc.WIRE_PROP.get(field), int(value), dt, label))

        if self.film_simulation is not None:
            add("film_simulation", self.film_simulation, "u16",
                f"FilmSim={self.film_simulation.name}")
        if self.grain is not None:
            add("grain", self.grain, "u16", f"Grain={self.grain.name}")
        if self.color_chrome_effect is not None:
            add("color_chrome_effect", self.color_chrome_effect, "u16",
                f"ColorChromeFX={self.color_chrome_effect.name}")
        if self.color_chrome_blue is not None:
            add("color_chrome_blue", self.color_chrome_blue, "u16",
                f"ColorChromeBlue={self.color_chrome_blue.name}")
        if self.noise_reduction is not None:
            add("noise_reduction", self.noise_reduction, "u16",
                f"NR={self.noise_reduction.name}")
        if self.dynamic_range is not None:
            add("dynamic_range", self.dynamic_range, "u16", f"DR={self.dynamic_range.name}")
        if self.color_space is not None:
            add("color_space", self.color_space, "u16", f"ColorSpace={self.color_space.name}")

        if self.highlight_tone is not None:
            v = _clamp("highlight_tone", round(self.highlight_tone * 10), oc.TONE_RANGE)
            add("highlight_tone", v, "i16", f"Highlight={self.highlight_tone:+}")
        if self.shadow_tone is not None:
            v = _clamp("shadow_tone", round(self.shadow_tone * 10), oc.TONE_RANGE)
            add("shadow_tone", v, "i16", f"Shadow={self.shadow_tone:+}")
        if self.color is not None:
            v = _clamp("color", self.color * 10, oc.COLOR_RANGE)
            add("color", v, "i16", f"Color={self.color:+}")
        if self.sharpness is not None:
            v = _clamp("sharpness", self.sharpness * 10, oc.SHARPNESS_RANGE)
            add("sharpness", v, "i16", f"Sharp={self.sharpness:+}")
        if self.clarity is not None:
            v = _clamp("clarity", self.clarity * 10, oc.CLARITY_RANGE)
            add("clarity", v, "i16", f"Clarity={self.clarity:+}")

        if self.mono_warm_cool is not None or self.mono_red_green is not None:
            wc = _clamp("mono_warm_cool", self.mono_warm_cool or 0, oc.MONO_COLOR_RANGE)
            rg = _clamp("mono_red_green", self.mono_red_green or 0, oc.MONO_COLOR_RANGE)
            add("mono_color", (rg & 0xFFFF) << 16 | (wc & 0xFFFF), "u32",
                f"MonoColor WC={wc:+} R/G={rg:+}")

        if self.white_balance is not None:
            add("white_balance", self.white_balance, "u16", f"WB={self.white_balance.name}")
        # WB shift là 2 property riêng (Red 0xD00B, Blue 0xD00C), i16, giá trị thô -9..9
        if self.wb_shift_red is not None:
            r = _clamp("wb_shift_red", self.wb_shift_red, oc.WB_SHIFT_RANGE)
            add("wb_shift_red", r, "i16", f"WBShift R={r:+}")
        if self.wb_shift_blue is not None:
            b = _clamp("wb_shift_blue", self.wb_shift_blue, oc.WB_SHIFT_RANGE)
            add("wb_shift_blue", b, "i16", f"WBShift B={b:+}")

        return w
