// Invoice arithmetic: line amounts, discount, tax and total, each rounded half to even to the cent.

const rates = require("../data/rates.json");
const { roundHalfEven } = require("./round");

function lineAmount(line) {
  if (line.quantity < 0 || line.unitPrice < 0) {
    throw new Error("quantity and unit price must not be negative");
  }
  return roundHalfEven(line.quantity * line.unitPrice);
}

function subtotal(lines) {
  return roundHalfEven(lines.reduce((sum, line) => sum + lineAmount(line), 0));
}

function discountAmount(subtotalValue, discount) {
  if (!discount) return 0;
  if (discount.percent !== undefined) {
    return roundHalfEven(subtotalValue * discount.percent / 100);
  }
  return Math.min(roundHalfEven(discount.amount), subtotalValue);
}

function taxRate(region) {
  if (!(region in rates)) {
    throw new Error(`no tax rate for region ${region}`);
  }
  return rates[region];
}

function totals(invoice, region) {
  const sub = subtotal(invoice.lines);
  const discount = discountAmount(sub, invoice.discount);
  const taxable = roundHalfEven(sub - discount);
  const tax = roundHalfEven(taxable * taxRate(region));
  return { subtotal: sub, discount, taxable, tax, total: roundHalfEven(taxable + tax) };
}

module.exports = { lineAmount, subtotal, discountAmount, taxRate, totals };
