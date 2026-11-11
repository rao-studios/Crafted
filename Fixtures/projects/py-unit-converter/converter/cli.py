"""Command line: convert a value, or print a table of conversions."""

import argparse

from .config import DEFAULT_PRECISION
from .length import convert_length
from .mass import convert_mass
from .temperature import convert_temperature
from .units import LENGTH, MASS, TEMPERATURE


def convert(value, from_unit, to_unit):
    """Pick the converter by the units' kind."""
    if from_unit in LENGTH and to_unit in LENGTH:
        return convert_length(value, from_unit, to_unit)
    if from_unit in MASS and to_unit in MASS:
        return convert_mass(value, from_unit, to_unit)
    if from_unit in TEMPERATURE and to_unit in TEMPERATURE:
        return convert_temperature(value, from_unit, to_unit)
    raise ValueError(f"cannot convert {from_unit} to {to_unit}")


def table(from_unit, to_unit, start, stop, step):
    """Rows of (value, converted) from start to stop."""
    rows = []
    value = start
    while value <= stop:
        rows.append((value, convert(value, from_unit, to_unit)))
        value += step
    return rows


def main(argv=None):
    parser = argparse.ArgumentParser(prog="convert")
    parser.add_argument("value", type=float)
    parser.add_argument("from_unit")
    parser.add_argument("to_unit")
    parser.add_argument("--precision", type=int, default=DEFAULT_PRECISION)
    parser.add_argument("--table", nargs=2, type=float, metavar=("STOP", "STEP"))
    args = parser.parse_args(argv)
    if args.table:
        for value, converted in table(args.from_unit, args.to_unit, args.value, *args.table):
            print(f"{value:g}\t{round(converted, args.precision)}")
    else:
        print(round(convert(args.value, args.from_unit, args.to_unit), args.precision))


if __name__ == "__main__":
    main()
