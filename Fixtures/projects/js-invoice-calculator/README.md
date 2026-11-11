# Invoice Calculator

Totals an invoice: each line's amount, discounts, sales tax by region, and the grand total, every amount rounded
half to even ("banker's rounding") to the cent.

    node src/cli.js samples/invoice.json
    node src/cli.js samples/invoice.json --region NY

An invoice is JSON: `{"lines": [{"description": "...", "quantity": 2, "unitPrice": 19.99}], "discount": {"percent": 10}}`.
A discount is a percent or a fixed amount, applied before tax. Tax rates by region are in `data/rates.json`.
