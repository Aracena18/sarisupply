# SariSupply performance delivery — 2026-10-07

Status: client and backend code implemented; scoped checks, physical-device component benchmarks and all three release APK updates pass. Manual authenticated flow acceptance and backend deployment remain pending. This is not production or full flow acceptance.

## Implemented behavior

- Shared injectable company controller isolates user/company/context/authorization revision and warehouse datasets. Identical reads share work, at most three requests run together, stale generations cannot replace newer rows, and refresh keeps previous rows visible. Operational freshness is 30 seconds; warehouses/payment instructions use five minutes. Foreground return and section entry check freshness; no polling.
- Company work loads warehouses first, then the active section; orders/runs dependencies load on demand. Stock uses the stock projection already returned with products. Product pickers reuse the controller's loaded pages, search them immediately, retain pagination and distinguish partial-catalog searches. Native picker queries debounce 200 ms. Company lists and pickers build lazily with stable record keys.
- Relevant saves invalidate products/stock, orders or runs while preserving unrelated datasets. Refresh re-reads all previously loaded pages. Company mutations report success only after server acceptance; durable retry IDs remain unchanged.
- POS management retains separate section pages/cursors within current membership scope. Catalog sync keeps visible content available. Company navigation retains scroll/expanded records and warehouse selection. Existing authorized local snapshots appear before network refresh; cached company data is labeled with saved time. Definitive denial clears display caches and disables work without deleting durable drafts/outboxes. POS company-order entry carries membership revision and branch permissions into the company cache scope.
- Company and legacy Driver proof commits return before eligible background uploads. Legacy upload denials propagate to stop/home screens to hide assignments and disable work, while durable outboxes remain intact. Stock receiving ignores duplicate submit taps. Pending local run projections survive background refresh. Rider authority remains limited to the existing seven-day, same-boot window, is rechecked at the local proof commit boundary after form confirmation, and is renewed only by a fresh successful server run read.
- Backend related product stock, canonical store order and rider lookup documents use bounded batch reads. Authorization document snapshots are reused within one transaction attempt only. Every new command/retry rechecks current authority; ownership and response contracts are preserved.
- Timeline traces separate company reads, auth token, App Check, HTTP, SQLite search, receiving, checkout and proof commits. No secrets or payloads are recorded. No dependency or SQLite schema changes.
- The shared form helper now waits for dialog teardown before caller-owned controllers are disposed. Focused lifecycle regression checks cover the current company forms.

## Physical phone results

20 repetitions per measured component operation, profile mode, Android 16 phone model 2510DRA23G. Baseline source was copied from the pre-change snapshots into an isolated temporary checkout. Both runs used identical fixture code, native SQLite, 1,000 products, real CheckoutController and ManagementScreen, isolated temporary databases and no real business/server mutations. These tests do not modify stock, sales, grants or customer records.

Navigation uses a controlled 200 ms repository delay to demonstrate the cost of redundant reads. It measures a tap through the next rendered record, including test pump overhead, on primed Branches/Team sections. It is not a measurement of Development API latency. SQLite search excludes the UI debounce. Local commits exclude form entry and upload. Checkout sale includes payment draft persistence and the atomic financial commit. Small differences in local timings should be treated as device-run variation; no SQLite query optimization is claimed.

| Operation | Before p95 | After p95 |
|---|---:|---:|
| Warm management navigation | 240.63 ms | 20.25 ms |
| Native SQLite search | 17.28 ms | 14.16 ms |
| Checkout cart addition (including draft save) | 19.12 ms | 16.39 ms |
| Atomic local receiving commit | 22.67 ms | 18.72 ms |
| Atomic local proof/outbox commit | 19.07 ms | 13.23 ms |
| Payment draft + atomic sale commit | 88.96 ms | 51.81 ms |

Warm navigation added 20 repository reads before, zero after. The measured navigation, local search, cart-add and local commit samples meet their respective component targets. Picker reopening request reuse also passes focused controller checks, but full picker selection/reopening on authenticated company screens has not been timed on the phone.

Raw samples: [PERFORMANCE-2026-10-07.samples.json](PERFORMANCE-2026-10-07.samples.json).

Reproduce from `apps/pos`:

```bash
adb shell am force-stop com.sarisupply.sarisupply_pos.dev
flutter drive --target=integration_test/performance_device_test.dart \
  --driver=test_driver/performance_driver.dart --profile --flavor dev \
  -d <phone-id> --keep-app-running \
  --dart-define=SARISUPPLY_PERF_PHASE=after
```

Use `--keep-app-running`: Flutter drive's default cleanup uninstalls its package. The first failed fixture attempt triggered an unsuccessful uninstall of the unflavored package, which was not installed. The `.dev` package and its data stayed installed. Later runs explicitly keep the app, force-stop before launch to avoid connecting to an old VM, and replace it with the final application APK. Private backups of all three app data directories and previous APKs were captured before profile installs; backups are outside the repository.

Following [Flutter profiling guidance](https://docs.flutter.dev/perf/ui-performance), these are physical profile-mode measurements; debug timings are not release evidence.

## Verification

- Scoped analysis: Admin/POS/Driver libraries, shared company/Firebase/inventory/design-system libraries, controller and benchmark tests, with no issues. Reanalysis of final changed management/company/benchmark code also passes.
- Admin controller/form lifecycle: 10 tests passed, including pagination-error retry within the freshness window. POS management/checkout controller: 10 tests passed, including revoked-access cache clearing and disabled work.
- Inventory proof/outbox, checkout rollback/immutability/reopen, delivery durability: 20 tests passed. HTTPS gateway: 12 tests passed.
- Driver location/permission and environment checks: 10 tests passed; final Driver analysis passes.
- Backend TypeScript build and four focused operations/read/authorization/HTTPS command files: 23 tests passed. Architecture boundary checker passed. Changed tracked-file whitespace check passed.
- Final Admin/POS/Driver Android dev release builds and Admin release web build passed. All Android APKs installed with `adb install --no-streaming -r` after all three signing certificates matched the previous installed APKs. Original first-install timestamps remain unchanged; installed apps are not debuggable. Each launched successfully, retained a running process, and had no native startup crash. No app data was cleared. Admin web compilation is a compatibility check, not web runtime acceptance.

The full harness, emulator suites and heavy UI matrices remain deferred per repository presentation-build instructions. Root-wide analysis encounters unrelated errors in the `sarisupply_design_system_v1` reference project; actual affected application/package analysis passes. Global whitespace checking also encounters an unrelated blank EOF in `firebase/functions/deno.json`; scoped changed-file checking passes.

## Installed release artifacts

Build settings: `--release --flavor dev --dart-define=SARISUPPLY_ENV=dev --dart-define=SARISUPPLY_API_URL=https://aracena18-sarisupply-dev-api.aracena18.deno.net` (web omits flavor). The early POS generated integration-test plugin conflict was resolved by serializing final Flutter tests/builds. Existing Java/Kotlin toolchain compatibility warnings remain; builds exit successfully.

| App | APK | Size |
|---|---|---:|
| Admin | [app-dev-release.apk](../../apps/admin/build/app/outputs/flutter-apk/app-dev-release.apk) | 58.29 MB |
| Pos | [app-dev-release.apk](../../apps/pos/build/app/outputs/flutter-apk/app-dev-release.apk) | 79.99 MB |
| Driver | [app-dev-release.apk](../../apps/driver/build/app/outputs/flutter-apk/app-dev-release.apk) | 57.77 MB |

Artifact hashes and install/startup evidence: [PERFORMANCE-2026-10-07.install.json](PERFORMANCE-2026-10-07.install.json). Startup checks do not establish authenticated UI acceptance.

## Remaining acceptance and limits

- User-led real workflows: rapid warehouse switching, background refresh while entering forms, failed refresh/offline restart, picker reopening/search/later-page refresh, authorization revocation and pending proofs surviving refresh/upload. Focused controller/durability checks establish relevant logic, but do not replace these authenticated phone flows.
- End-to-end stock receiving and proof saving, picker selection, token/App Check/HTTP stage timing, and frame/render traces on real business data are still unmeasured. Trace instrumentation is ready; no full production-latency target is claimed.
- Backend optimization code is built/tested locally and has not been deployed by this delivery. APKs use the existing Development endpoint. Live backend benefits require deployment and authenticated acceptance.
- Preserve current design, permissions, money policy and offline authorization. No application uninstall/data clearing or SQLite migration is needed.
