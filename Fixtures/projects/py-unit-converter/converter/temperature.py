"""Temperature conversion between Celsius, Fahrenheit and Kelvin."""

ABSOLUTE_ZERO_C = -273.15


def to_celsius(value, unit):
    if unit == "C":
        return value
    if unit == "F":
        return (value - 32) * 5 / 9
    if unit == "K":
        return value - 273.15
    raise ValueError(f"unknown temperature unit: {unit}")


def from_celsius(value, unit):
    if unit == "C":
        return value
    if unit == "F":
        return value * 9 / 5 + 32
    if unit == "K":
        return value + 273.15
    raise ValueError(f"unknown temperature unit: {unit}")


def convert_temperature(value, from_unit, to_unit):
    """Convert a temperature, refusing one below absolute zero."""
    celsius = to_celsius(value, from_unit)
    if celsius < ABSOLUTE_ZERO_C:
        raise ValueError("below absolute zero")
    return from_celsius(celsius, to_unit)
