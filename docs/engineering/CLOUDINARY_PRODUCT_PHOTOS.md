# Cloudinary product photos

Approved on 2026-10-06: one public product photo per merchant catalog product,
managed by Owners in Android POS. Camera and gallery selection, online upload,
replacement/removal, and cached offline viewing are included. Logos, delivery
photos, private media, video, bulk import, and offline upload queues are excluded.
The existing design language and all financial/offline authorization rules remain.

## Architecture and contract

The existing Deno HTTPS gateway exposes `prepareProductImageUpload` and
`completeProductImageUpload`. Both require Firebase Auth, App Check and current
merchant Owner authority. Media bytes upload directly to Cloudinary, never to
Firestore or the Deno JSON command endpoint. Only the trusted backend has the API
secret; no unsigned upload preset is enabled.

Preparation reserves a stable upload ID and signs fixed format, transformation,
eager-derivative, no-overwrite and no-backup options. Public IDs include deployment
environment and hashes binding merchant, product and upload IDs. Completion reads
authoritative Cloudinary asset metadata, rejects unsupported/oversized/animated
assets, and saves a verified draft reference. The client cannot claim an asset
by supplying a URL, asset ID or a provider response.

`saveCatalogProduct` accepts optional `imageChange`:

- `{action: 'keep'}` or omitted: preserve current managed image and legacy URL.
- `{action: 'set', uploadId: '...'}`: atomically attach a verified, unexpired draft
  for this merchant/product/owner alongside the product revision and catalog delta.
- `{action: 'remove'}`: clear image reference and URL explicitly.
- `{action: 'url', url: 'https://...'}`: retain existing preset/custom HTTPS URL
  controls, without granting Cloudinary asset ownership or cleanup rights.

Products retain `imageUrl` and optional `image` with asset/public ID, version,
640-pixel delivery URL and 160-pixel thumbnail URL. SQLite's existing JSON product
body stores these fields without a database migration. Archive/restore preserves
photos. Immutable receipt and sale records are not changed.

A selected file stays a form draft until Save. Upload and uncertain-save retries
preserve IDs. Successful verification is retained in the mounted form, avoiding
repeat uploads after a product-save error. Closing/restarting the form discards
its image draft; abandoned cloud uploads are eligible for cleanup after 24 hours.
Interrupted Android picker results are recovered, but unsaved product form fields
are not promised to survive process death. Existing photos remain authoritative
until product save succeeds.

## Private Development setup

1. Use a **signed** upload preset and keep paid add-ons off. The backend signs
   an allowlist of jpg/png/webp, no-overwrite/no-backup options, normalization to
   a maximum 1024-pixel edge, quality 80 and stripped embedded profiles/metadata.
   It requests fixed 160 and 640 pixel WebP derivatives. Do not enable unsigned
   uploads for this preset.
2. Set these private backend environment values through the Deno environment
   settings or an owner-controlled environment file outside the repository. The
   local Development Cloudinary values are stored at
   `~/.config/sarisupply/dev-cloudinary.env`; for local Deno runs, pass
   `--env-file="$HOME/.config/sarisupply/dev-cloudinary.env"`:

   ```text
   CLOUDINARY_CLOUD_NAME=<cloud name>
   CLOUDINARY_API_KEY=<API key>
   CLOUDINARY_API_SECRET=<API secret>
   CLOUDINARY_UPLOAD_PRESET=<signed preset name>
   CLOUDINARY_UPLOADS_ENABLED=false
   ```

   Never commit credentials, pass the secret as a command argument, put it in
   Flutter build flags, or include it in screenshots/logs/chat. The API key/cloud
   name are public upload parameters; the API secret is not.
3. Build the backend with `npm run build` in `firebase/functions`, then deploy the
   compiled Development backend using the existing deployment procedure.
4. Set `CLOUDINARY_UPLOADS_ENABLED=true` only for Development when configuration
   is complete. `mediaSettings/cloudinary` with `uploadsEnabled: false` is an
   additional trusted Firestore emergency switch. Clients cannot write it.
5. Perform the live acceptance checks below before enabling Production.

The Development credentials in the workspace were validated against the selected
SariSupply Cloudinary account and copied to the private local environment file
with uploads disabled. The operator has configured the Deno Production runtime
context for the Development app; the API secret is stored as a secret and the
upload flag remains false. Deployment of the compiled Cloudinary-enabled backend,
live upload/cross-device sync, camera/permission and offline-device acceptance
remain pending. Existing catalog/sales work without Cloudinary settings. Do not
represent local verification as hosted acceptance.

## Free limits and operator actions

Client selection allows static JPEG/PNG/WebP up to 5 MiB; completion independently
checks stored asset type, size, dimensions and animation metadata. Cloudinary
normalizes the stored image, so post-upload validation does not prove the original
client file's size. These controls reduce abuse; a signed direct-upload authority
is not a one-use file-content signature. Cloudinary signatures have provider-defined
validity (currently one hour), while unique IDs with overwrite disabled prevent
replacing the authorized image. Do not describe them as instantly revocable URLs.

Cloudinary Free currently provides 25 credits shared across storage,
transformations and image bandwidth. The backend warns at 17.5 credits and stops
preparation at 20. Usage is cached for 15 minutes; unavailable checks deny new
preparation. New IDs reserve daily allowances: 50 per merchant and 200 globally
per backend/database, plus conservative reservations in each 15-minute window.
Retries of the same valid upload do not consume another daily slot. Use separate
Cloudinary environments/accounts for dev/prod; daily counters are not aggregated
across separate Firebase databases. CDN bandwidth and provider reporting lag mean
these safeguards are not a strict account-spending or availability guarantee.
No automatic paid upgrade or paid fallback exists.

Photos are public. Removing a photo does not instantly revoke externally cached
copies. The dedicated Android disk cache evicts completed downloads beyond
100 MiB and has a 3000-object ceiling. Cached photos survive ordinary app restarts;
Android may clear app cache storage. Cache misses use the existing category/icon
fallback. Web uses browser caching; durable offline caching targets Android POS.
Image downloads never participate in financial commits or block catalog sync.

Run daily using the same private backend configuration, from `firebase/functions`:

```bash
npm run build
npm run cleanup:photos
```

Each invocation processes up to 50 due upload records. Repeat while `hasMore` is
true. Unattached and replaced assets have a 24-hour grace period. Cleanup checks
current product references, protects archived products, claims records before
external deletion, and prevents concurrent attachment after the claim. Failed
deletions remain `deleting` and retry on the next run. Results expose counts only.
Do not remove upload records manually while cleanup or save is in progress.

## Acceptance and rollback

Local checks: workspace analysis, TypeScript build, architecture check and focused
model, upload adapter, lifecycle/authorization and cache tests. Full emulator and
heavy UI matrices remain deferred under the repository's build-focused workflow.

Development manual acceptance:

- Owner camera/gallery upload, cancel and deny permissions; invalid/large files.
- Product save and photo appearance on a second authorized POS after catalog sync.
- Restart a device offline: previously downloaded image renders; uncached image
  uses fallback. Checkout remains usable during image-service failure.
- Replace/remove, interrupted upload, uncertain save retry and stale revision.
- Manager/device/foreign-merchant denial and owner revocation between upload/save.
- Quota/service failure retains the old photo. Daily cleanup retains attached and
  archived images, deletes abandoned/replaced images, and retries failed deletion.
- Verify normalized dimensions, static WebP derivatives, stripped metadata and
  actual account credits in Cloudinary before scaling catalog bootstrap.

Rollback: set `CLOUDINARY_UPLOADS_ENABLED=false` or the trusted Firestore switch.
Existing photos, products, sales and pending financial operations remain intact.
Keep the new backend read/save compatibility when rolling back client photo UI;
older code that discards image fields must not be redeployed over managed images.

References: [signed uploads](https://cloudinary.com/documentation/client_side_uploading),
[Upload API](https://cloudinary.com/documentation/image_upload_api_reference),
[Admin API](https://cloudinary.com/documentation/admin_api),
[pricing](https://cloudinary.com/pricing),
[credit accounting](https://cloudinary.com/documentation/billing_and_plans).

## Local verification evidence (2026-10-06)

- `dart run melos exec --fail-fast --concurrency=1 -- flutter analyze --no-pub`:
  PASS, all nine workspace packages, zero issues.
- `npm run build` in `firebase/functions`: PASS.
- Focused backend media and HTTPS command tests: 11 PASS, including compatibility
  with catalog idempotency receipts written before image support.
- Focused Flutter tests: 12 PASS (4 model/catalog, 2 upload adapter, 3 cache/image,
  3 POS format/form/retry). The disk-cache test proves restart recovery without
  network and byte-budget eviction. These are local checks, not hardware evidence.
- `dart tool/check_architecture.dart` and `git diff --check`: PASS.
- POS `flutter build apk --debug --flavor dev`: PASS. This compilation check does
  not configure the live backend or install the APK. Gradle emitted existing
  toolchain/Firebase-plugin compatibility warnings; Dart workspace analysis is clean.
- The raw root-wide `flutter analyze` also scans the unbootstrapped
  `sarisupply_design_system_v1` reference copy and reports missing package imports
  there. The authoritative Melos workspace analysis above passes; that separate
  reference copy was not modified for this feature.
- `verify_fast.sh` (which runs all package tests), the heavy verification harness
  and full emulator suites were not run under the requested light-building rules.
- Development deploy, Cloudinary live/account/preset verification and manual
  camera, permission, second-device sync and real offline acceptance remain pending.
