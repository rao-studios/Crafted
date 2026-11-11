"""Conversion factors: each unit in the base unit of its kind."""

# Length: metres per unit.
LENGTH = {
    "mm": 0.001,
    "cm": 0.01,
    "m": 1.0,
    "km": 1000.0,
    "in": 0.0254,
    "ft": 0.3048,
    "yd": 0.9144,
    "mi": 1609.344,
}

# Mass: kilograms per unit.
MASS = {
    "mg": 0.000001,
    "g": 0.001,
    "kg": 1.0,
    "oz": 0.028349523125,
    "lb": 0.45359237,
    "st": 6.35029318,
}

TEMPERATURE = ("C", "F", "K")
