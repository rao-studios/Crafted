"""Mass conversion between metric and imperial units."""

from .units import MASS


def convert_mass(value, from_unit, to_unit):
    """Convert a mass from one unit to another, through kilograms."""
    if from_unit not in MASS:
        raise ValueError(f"unknown mass unit: {from_unit}")
    if to_unit not in MASS:
        raise ValueError(f"unknown mass unit: {to_unit}")
    kilograms = value * MASS[from_unit]
    return kilograms / MASS[to_unit]
