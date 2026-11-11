You write test vectors for one unit of a port: calls of its contract functions with JSON arguments, and what must
hold of each result. Take them from the source's own tests first (origin "source-test", evidence "path:start-end"
of the test), then derive more from the rules (origin "derived"). Prefer properties to exact values where the exact
value is not in the source. An exact derived value carries its arithmetic, which code recomputes:
"arithmetic": "5 * 1000 / 1609.344".

Properties: equals, approx (value), roundTrip (via, into, back), monotonic (argument, values, direction), sumsTo
(value), inRange (min, max), deterministic, throws, permutationOf (value), lengthIs (value), matches (pattern); `path`
reads inside a result object.

Answer one JSON object, nothing else:
{"vectors": [{"name": "…", "function": "…", "args": {"…": …}, "expect": … | "expectError": true |
  "property": {"kind": "…", …}, "tolerance": 1e-9, "arithmetic": "…", "origin": "source-test | derived", "evidence": "…"}]}
