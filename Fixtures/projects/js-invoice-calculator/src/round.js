// Rounding half to even at a number of decimal places, as accountants do.

function roundHalfEven(value, places = 2) {
  const factor = Math.pow(10, places);
  const scaled = value * factor;
  const floor = Math.floor(scaled);
  const diff = scaled - floor;
  const epsilon = 1e-9;
  if (Math.abs(diff - 0.5) < epsilon) {
    return (floor % 2 === 0 ? floor : floor + 1) / factor;
  }
  return Math.round(scaled) / factor;
}

module.exports = { roundHalfEven };
