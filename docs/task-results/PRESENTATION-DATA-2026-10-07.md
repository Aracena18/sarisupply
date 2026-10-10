# Development presentation stock — 2026-10-07

Applied to Firebase project `sarisupply-dev-aracena18`, Beta Store / Main branch,
and SariSupply warehouse Robert. No Production data was used.

| Data | Before | After |
| --- | ---: | ---: |
| Active store catalog products | 38 | 62 |
| Active company catalog products | 4 | 62 |
| Store stock records | 30 | 62 |
| Warehouse stock records | 4 | 62 |

The result includes 50 grocery demo items (20 newly added) and the 12 existing
test items. Every active item now has a counterpart, matching base unit, photo
link and primary barcode, plus an explicit 1:1 base-unit mapping. Company and
store product IDs and stock ledgers remain distinct. Existing retail/wholesale
prices, managed store images, historical orders/payments and stock balances were
preserved. New stock uses the ordinary opening-stock and warehouse-receipt
services and their immutable receipts/events.

[Grocery catalog CSV](PRESENTATION-CATALOG-2026-10-07.csv) lists all 50 grocery
items, their retail/wholesale prices, stock, primary/pack barcodes and photo links.
The 113 total unit codes are internal presentation EAN-13 numbers, not
manufacturer GTINs. Photo links are representative category photographs rather
than exact manufacturer package photographs. The replacement canned-food image
is by [Haberdoedas on Unsplash](https://unsplash.com/photos/a-can-of-sardines-is-seen-with-lemon-ucKNV2x8PXE).

Verification passed:

- 62 active product pairs; equal names, base units, primary barcodes and photo links.
- Stock records and 1:1 product mappings for every pair.
- All 30 pre-existing retail and four warehouse balances/revisions unchanged.
- 113 unique numeric barcodes with valid EAN-13 checksums; all photo URLs return images.
- 62 contiguous catalog changes and 32 contiguous stock changes in the POS feeds.
- Seed replay for Tuna Flakes changed no stock, revisions or feed cursors.
- Firebase Functions TypeScript build and seed script syntax checks.

The seed uses [trusted operator tooling](../../firebase/functions/tool/README.md)
with current Firebase Auth identities and server-side business authorization.
Private original-document backup, replay plan and verification reports are stored
under `~/.config/sarisupply/presentation-seed-20261007-v1/`, outside the repository.
No credentials are included in the catalog file or tooling.

Sync POS and refresh Admin Stock to download these records. On-device display
acceptance remains manual; APK builds, API deployment and full harness/emulator
runs were unnecessary for this data-only change and were not performed.
