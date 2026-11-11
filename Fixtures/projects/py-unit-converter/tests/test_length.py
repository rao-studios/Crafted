import pytest

from converter.length import convert_length


def test_kilometres_to_miles():
    assert convert_length(5, "km", "mi") == pytest.approx(3.106856, abs=1e-6)


def test_feet_to_metres():
    assert convert_length(10, "ft", "m") == pytest.approx(3.048)


def test_unknown_unit():
    with pytest.raises(ValueError):
        convert_length(1, "furlong", "m")
