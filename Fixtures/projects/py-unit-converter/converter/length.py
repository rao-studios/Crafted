"""Length conversion between metric and imperial units."""

from .units import LENGTH


def convert_length(value, from_unit, to_unit):
    """Convert a length from one unit to another, through metres."""
    if from_unit not in LENGTH:
        raise ValueError(f"unknown length unit: {from_unit}")
    if to_unit not in LENGTH:
        raise ValueError(f"unknown length unit: {to_unit}")
    metres = value * LENGTH[from_unit]
    return metres / LENGTH[to_unit]
