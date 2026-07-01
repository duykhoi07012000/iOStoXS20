"""Test mapping recipe → PTP property writes (chạy được KHÔNG cần camera)."""

import struct

import pytest

from fuji_xs20 import opcodes as oc
from fuji_xs20.recipe import Recipe


def _by_code(writes, code):
    for w in writes:
        if w.code == code:
            return w
    raise AssertionError(f"Không tìm thấy write cho 0x{code:04X}")


def test_film_sim_and_basic_codes():
    w = Recipe(film_simulation=oc.FilmSimulation.CLASSIC_NEG).to_property_writes()
    assert _by_code(w, oc.Prop.FILM_SIMULATION).value == 0x11


def test_tone_scaled_by_ten():
    w = Recipe(highlight_tone=1.5, shadow_tone=-2.0).to_property_writes()
    assert _by_code(w, oc.Prop.HIGHLIGHT_TONE).value == 15
    assert _by_code(w, oc.Prop.SHADOW_TONE).value == -20


def test_noise_reduction_bucket():
    w = Recipe(noise_reduction=oc.NoiseReduction.M4).to_property_writes()
    assert _by_code(w, oc.Prop.NOISE_REDUCTION).value == 0x8000


def test_wb_shift_packing():
    w = Recipe(wb_shift_red=2, wb_shift_blue=-5).to_property_writes()
    packed = _by_code(w, oc.Prop.WHITE_BALANCE_TUNE).value
    r = packed & 0xFFFF
    b = struct.unpack("<h", struct.pack("<H", (packed >> 16) & 0xFFFF))[0]
    assert r == 2 and b == -5


def test_only_set_fields_emit_writes():
    assert Recipe(name="empty").to_property_writes() == []
    assert len(Recipe(color=1, sharpness=2).to_property_writes()) == 2


def test_out_of_range_rejected():
    with pytest.raises(ValueError):
        Recipe(clarity=99).to_property_writes()
    with pytest.raises(ValueError):
        Recipe(wb_shift_red=20).to_property_writes()


def test_from_dict_enum_by_name():
    r = Recipe.from_dict({"name": "x", "film_simulation": "ETERNA",
                          "white_balance": "DAYLIGHT"})
    assert r.film_simulation is oc.FilmSimulation.ETERNA
    assert r.white_balance is oc.WhiteBalance.DAYLIGHT


def test_from_dict_rejects_unknown_field():
    with pytest.raises(ValueError):
        Recipe.from_dict({"bogus": 1})
