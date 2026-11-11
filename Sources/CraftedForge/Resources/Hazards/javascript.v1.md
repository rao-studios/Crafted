# JavaScript to Swift: what ports get wrong

- Every number is a Double. `Math.round(x)` rounds half toward positive infinity (Math.round(-2.5) is -2); Swift's
  `rounded()` rounds half away from zero (-3). `toFixed(2)` rounds the decimal string, not the binary value.
- `Math.floor` on a negative number floors; Swift's Int(x) truncates toward zero. Use `x.rounded(.down)`.
- `x % y` takes the dividend's sign, as Swift does, but works on Doubles: use `truncatingRemainder(dividingBy:)`.
- `a || b` and `a ?? b` differ: `||` falls through on 0 and "". Port the one the source wrote.
- `undefined` and `null` both read as "no value" in `== null`; a missing key in an object is `undefined`. Model them
  as optionals and say which keys are optional in the contract.
- `Number(...)`, `parseFloat` and `parseInt` accept leading numbers and return NaN on failure; Swift's `Double(_:)`
  returns nil on any trailing text.
- Sorting with no comparator sorts as strings ([10, 9, 1] becomes [1, 10, 9]).
- `Array.reduce` without an initial value takes the first element; give Swift's `reduce` the same start.
- `new Error("…")` thrown is `throw CoreFailure.invalid("…")`, its sentence saying the fix.
- `require("../data/x.json")` reads a carried table: `CoreResources.json(Type.self, "x.json")`.
