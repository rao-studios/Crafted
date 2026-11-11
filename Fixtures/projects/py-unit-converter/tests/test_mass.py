import pytest

from converter.mass import convert_mass


def test_pounds_to_kilograms():
    assert convert_mass(1, "lb", "kg") == pytest.approx(0.45359237)


def test_stone_to_pounds():
    assert convert_mass(1, "st", "lb") == pytest.approx(14.0)


def test_unknown_unit():
    with pytest.raises(ValueError):
        convert_mass(1, "grain", "g")
