#!/usr/bin/env node
// Prints an invoice's totals: node src/cli.js invoice.json [--region NY]

const fs = require("fs");
const { totals } = require("./invoice");
const { DEFAULT_REGION } = require("./config");

function main(argv) {
  const file = argv[0];
  const at = argv.indexOf("--region");
  const region = at >= 0 ? argv[at + 1] : DEFAULT_REGION;
  const invoice = JSON.parse(fs.readFileSync(file, "utf8"));
  const result = totals(invoice, region);
  for (const [name, value] of Object.entries(result)) {
    console.log(`${name.padEnd(9)} ${value.toFixed(2)}`);
  }
}

main(process.argv.slice(2));
