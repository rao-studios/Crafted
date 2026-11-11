# Unit Converter

A small command-line tool that converts lengths, masses and temperatures, and prints conversion tables.

    python -m converter.cli 5 km mi
    python -m converter.cli 0 C F --table 100 10

Lengths: mm, cm, m, km, in, ft, yd, mi. Masses: mg, g, kg, oz, lb, st. Temperatures: C, F, K.

Results are rounded to four places unless `--precision` says otherwise, the way Python's `round` does.
Temperatures below absolute zero are refused.

Run the tests with `pytest`.
