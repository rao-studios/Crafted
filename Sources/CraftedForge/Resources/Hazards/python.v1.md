# Python to Swift: what ports get wrong

- `round(x, n)` rounds half to even ("banker's rounding"): round(2.5) is 2, round(0.125, 2) is 0.12. Swift's
  `rounded()` rounds half away from zero. Use `(x * p).rounded(.toNearestOrEven) / p` where p is 10^n.
- `/` is true division on ints too (7 / 2 is 3.5); `//` floors toward negative infinity (-7 // 2 is -4), Swift's `/`
  on Int truncates toward zero (-7 / 2 is -3).
- `%` takes the sign of the divisor (-7 % 3 is 2); Swift's `%` takes the dividend's (-7 % 3 is -1).
- Ints never overflow in Python; Swift's Int traps. Use Double or check the range where values can grow.
- A dict keeps insertion order; a Swift Dictionary does not. Keep an ordered array of keys when order shows.
- `while value <= stop: value += step` accumulates float error the same way in Swift only if the steps are the
  same Double additions: keep the loop, do not compute `start + i * step`.
- `raise ValueError(...)` is `throw CoreFailure.invalid("…")`, its sentence saying the fix.
- `str.split()` with no argument splits on runs of whitespace and drops empties; Swift's `split(separator: " ")`
  does not split on tabs or newlines.
- f-strings with `:g` or a precision format numbers; Swift's `"\(x)"` prints `3.0` for 3. Use `FactValue.format`-style
  formatting only in handlers; units return numbers.
- Truthiness: an empty list, 0, "" and None are false in Python. Swift needs the explicit test.
