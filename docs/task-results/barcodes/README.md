# Printable store barcodes — 07 October 2026

Store: **Beta Store / Main branch**. Barcode values were read from the current
Development Firebase store inventory. No inventory data was changed to generate
these documents.

## Documents

- `sari-store-all-barcodes-2026-10-07.pdf`: 113 sale-unit labels for 62 products,
  including individual items and packs; 8 A4 pages.
- `sari-store-base-unit-barcodes-2026-10-07.pdf`: one base-unit label per product,
  62 labels; 5 A4 pages.
- `sari-store-barcode-index-2026-10-07.csv`: product, SKU, sale unit, quantity
  factor, base unit, and exact barcode value for all 113 labels. Import the
  barcode column as text when opening in a spreadsheet.

## Printing and scanning

1. Print on A4, portrait, at **Actual size / 100%**, one PDF page per sheet.
   Disable Fit to page and multiple pages per sheet.
2. Keep the barcode black on white and preserve its surrounding white space.
   Cut along dotted outlines if separate labels are needed.
3. Sync the POS inventory before scanning so the newly seeded barcode values
   are available on the device.
4. Scan the label for the intended sale unit. Pack labels are distinct from
   individual-item labels and show their quantity factor.

The barcodes are EAN-13 demo identifiers for the presentation, not manufacturer
GTINs. Names and unit labels match the current inventory, including existing
trial products.

## Verification

- Every barcode has 13 numeric digits and a valid EAN-13 checksum.
- All 113 sale-unit barcode values are unique.
- Vector bars use a 0.3387 mm module, 22.85 mm height, and 11-module quiet zones
  on both sides.
- Both final PDFs were rendered at 300 dpi. ZXing-C++ decoded every label and
  returned its exact stored Firebase barcode: **113/113** and **62/62**.
- The first complete page was visually inspected for layout and readability.
- Physical print quality and scanning on the user's device remain for manual
  verification.

Machine-readable results: `barcode-pdf-verification-2026-10-07.json`.
