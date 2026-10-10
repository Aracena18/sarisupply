# Development presentation inventory

`seed-presentation.cjs` is trusted operator tooling for the Development
`beta-store` / `main-branch` and SariSupply's single active warehouse. It refuses
Production, inactive business scopes, ambiguous Owners/warehouses, and disabled
Owner accounts. Company authority also requires the verified Google identity and
current company role grant.

Build the existing server services, then prepare the private backup and plan:

```bash
cd firebase/functions
npm run build
node tool/seed-presentation.cjs \
  --service-account "$HOME/.config/sarisupply/firebase-dev-service-account.json" \
  --state-dir "$HOME/.config/sarisupply/presentation-seed-20261007-v1"
```

Review the private `plan.json`, then use the same command with `--apply` to write.
The October 7 presentation request authorizes that Development seed.

The tool mirrors existing active products, adds the 20 grocery products in
`presentation-products.json`, assigns internal numeric EAN-13 demo barcodes,
sets representative category photo links, and creates explicit one-to-one base
unit mappings. These barcodes are not manufacturer GTINs. Retail and wholesale
prices remain separate. Existing prices, product IDs, managed store photos and
stock balances are preserved. Missing retail stock receives an opening record;
missing warehouse stock receives an audited stock receipt.

Business writes invoke the existing trusted server services with identities
checked through Firebase Auth and current business authorization. The company
barcode metadata extension also checks the current Owner role transactionally
and records its trusted Admin SDK provenance. No client API, role grant, security
rule, device credential or installed application changes are required.

Keep the service account and state directory outside the repository. The private
state includes the original documents, exact operation payloads, and verification
result. Reuse that state directory when retrying: the stored operation IDs and
payloads allow service idempotency receipts to prevent duplicate opening stock.
Creating another state directory is not a supported way to reseed this version.

After writing, verification compares both active catalogs, base units, barcodes,
photos, mappings and stock records, and checks that pre-existing balances and
stock revisions remain unchanged. POS uses its normal catalog/stock change feeds;
refresh Admin Stock and sync POS to download the data.

Photos use existing public Unsplash category photographs, plus the canned-food
photograph by [Haberdoedas](https://unsplash.com/photos/a-can-of-sardines-is-seen-with-lemon-ucKNV2x8PXE).
The existing managed store photos remain public photo links on their company
counterparts; the company does not gain managed asset ownership.
