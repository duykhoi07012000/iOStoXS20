"""Test parser text recipe (chạy được không cần camera). Cũng là spec cho bản Swift."""

from fuji_xs20.recipe_parser import parse

COPENHAGEN = """FILM SIMULATION
の
Copenhagen Negative
Classic
Negative
DYNAMIC RANGE
DR400
GRAIN EFFECT
Strong Small
COLOR CHROME EFFECT
Weak
COLOR CHROME EFFECT BLUE
Strong
WB
5700K, t1 Red & +1 Blue
HIGHLIGHT
+2,5
SHADOW
-2
COLOR
+4
SHARPNESS
-2
NOISE REDUCTION/HIGH ISO NR
-4
CLARITY
-3
ISO
up to ISO 6400
EXPOSURE COMPENSATION
0 to -2/3"""

CINESTILL = """CineStill 800T
Film Simulation
Eterna / Cinema
Grain Effect
Large / Strong
Color Chrome Effect
Off
Color Chrome FX Blue
Strong
White Balance
Color Temperature, +2 Red, -4 Blue
Dynamic Range
DR200
Highlight
-1
Shadow
+2
Color
+4
Sharpness
-2
Noise Reduction
-4
Clarity
-3"""


def test_copenhagen_full():
    r = parse(COPENHAGEN)
    assert r["name"] == "Copenhagen Negative"
    assert r["film_simulation"] == "classicNeg"
    assert r["dynamic_range"] == "dr400"
    assert r["grain"] == "strongSmall"
    assert r["color_chrome_effect"] == "weak"
    assert r["color_chrome_blue"] == "strong"
    assert r["white_balance"] == "colorTemp"
    assert r["wb_kelvin"] == 5700
    assert r["wb_shift_red"] == 1 and r["wb_shift_blue"] == 1
    assert r["highlight_tone"] == 2.5 and r["shadow_tone"] == -2
    assert r["color"] == 4 and r["sharpness"] == -2 and r["clarity"] == -3
    assert r["noise_reduction"] == "m4"
    assert r["notes"]["iso"] == "up to ISO 6400"
    assert r["notes"]["exposure_compensation"] == "0 to -2/3"


KODACHROME = """Kodachrome 64
Classic Chrome
Dynamic Range: DR200
Highlight: 0
Shadow: 0
Color: +2
Noise Reduction: -4
Sharpening: +1
Clarity: +3
Grain Effect: Weak, Small
Color Chrome Effect: Strong
Color Chrome Effect Blue: Weak
White Balance: Daylight, +2 Red & -5 Blue
ISO: Auto, up to ISO 6400
Exposure Compensation: 0 to +2/3 (typically)"""


def test_kodachrome_inline_format():
    r = parse(KODACHROME)
    assert r["name"] == "Kodachrome 64"
    assert r["film_simulation"] == "classicChrome"
    assert r["dynamic_range"] == "dr200"
    assert r["highlight_tone"] == 0 and r["shadow_tone"] == 0
    assert r["color"] == 2 and r["sharpness"] == 1 and r["clarity"] == 3
    assert r["noise_reduction"] == "m4"
    assert r["grain"] == "weakSmall"
    assert r["color_chrome_effect"] == "strong"
    assert r["color_chrome_blue"] == "weak"
    assert r["white_balance"] == "daylight"
    assert r["wb_shift_red"] == 2 and r["wb_shift_blue"] == -5
    assert r["notes"]["iso"] == "Auto, up to ISO 6400"


def test_cinestill_variants():
    r = parse(CINESTILL)
    assert r["name"] == "CineStill 800T"
    assert r["film_simulation"] == "eterna"
    assert r["grain"] == "strongLarge"
    assert r["color_chrome_effect"] == "off"
    assert r["color_chrome_blue"] == "strong"
    assert r["white_balance"] == "colorTemp"
    assert r["wb_shift_red"] == 2 and r["wb_shift_blue"] == -4
    assert r["dynamic_range"] == "dr200"
    assert r["highlight_tone"] == -1 and r["shadow_tone"] == 2
    assert r["noise_reduction"] == "m4"


if __name__ == "__main__":
    test_copenhagen_full()
    test_cinestill_variants()
    test_kodachrome_inline_format()
    print("OK - parser pass ca 3 ca")
