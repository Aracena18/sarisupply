# UI redesign evidence

Implemented from the user-approved UI/UX audit plan on 2026-10-05. The authoritative presentation contract is [design.md](../../design.md).

## Scope and behavior

Shared teal/mango storefront branding, locally bundled Nunito Sans and OFL license, Material 3 theme, scalable task titles, status panels, and phone/page versus wide/dialog forms. Launcher and Admin web icons share the storefront; web manifest and page metadata use SariSupply branding.

POS access and onboarding distinguish loading, error, pending review, invitations, PIN change, revoked-device recovery, and expired offline access. Cashier names and manual ID selection are reversible; pending actions are guarded and PIN errors clear secrets. Invitations retain a store reference and readable local expiry; store-name enrichment is separate backend work.

Successful cashier sign-in verifies current device scope and opens Inventory directly. Lock invalidates pending verification and disposes Inventory. Management still signs in/out its separate human session. These actions do not delete stock files or pending counts.

Inventory rows show product, stock in base units and exact base price. Expansion reveals sale units and authorized actions. Exact barcode searches show the matched sale unit and exact price. Pending counts and review recovery are reachable above results; failures retain visible inventory. Count forms show current quantity, base unit, entered count and reason; withdrawal explains the local reversal and retained history.

Management uses a category selector on phones and side navigation on wide screens, with contextual creation actions and consequence-specific confirmations. Product, stock-count and management forms share a state-preserving responsive surface. Product units expand individually; immutable fields and retry IDs are preserved. Temporary PIN disclosure dismisses when the app loses foreground access.

Admin retains application search, adds structured review details and deliberate approval/rejection confirmation, preserves rejection notes and retry IDs, and guards sign-in/sign-out. Driver shows “No delivery workspace available” with no placeholder actions.

No business APIs, Firestore rules, SQLite schemas, arithmetic, or offline authorization policies were changed by this redesign. Concurrent checkout work in this checkout is separate.

## Deterministic screen and state coverage

| Surface | Evidence |
| --- | --- |
| Shared entry, branding, tap-target labels | `packages/sarisupply_design_system/test/brand_test.dart`, theme test |
| POS gate states, load retry, pending sign-in, direct entry, Lock and late verification | `apps/pos/test/features/pos_app_gate_test.dart` |
| Cashier names/loading/error/manual selection, secret clearing | `cashier_selection_test.dart` |
| New/draft/rejected applications; invitations/retry/pending acceptance; activation; temporary PIN and blocked states | POS `ui_redesign_test.dart`, `onboarding_activation_test.dart`, gate tests |
| Inventory rows/barcode/shortage, empty/error/sync failure, pending review, count/withdrawal context | `catalog_screen_test.dart`, POS `ui_redesign_test.dart` |
| Sole branch automatic entry; explicit multiple-branch choice; error/empty branch recovery | POS `ui_redesign_test.dart` |
| Product keyboard/12 units, resize, immutable fields, exact centavos/zero barcodes/retry | `product_dialog_test.dart`, POS `ui_redesign_test.dart` |
| All management form types, role/category scope, filtered-page pagination, confirmation, PIN dismissal/background protection | `management_screen_test.dart`, POS `ui_redesign_test.dart` |
| Admin sign-in/check/denied/error, queue/empty/error/search, detail and confirmation/retry/rejection notes | Admin `ui_redesign_test.dart`, `admin_review_flow_test.dart` |
| Driver inactive state | Driver `widget_test.dart` |

Responsive fixture checks cover **320, 390, 600, 1024 and 1280 logical pixels**, at **100% and 200% text size**. Twelve-unit product forms also run with keyboard insets; Inventory is resized with a live SQLite fixture. Admin sign-in has a Tab/Enter keyboard test. These are widget checks, not hardware usability evidence.

## Representative golden set

Six rendered fixtures use locally loaded fonts and Material icons. The images were visually inspected; they are a regression set, not speed measurements.

- [Entry branding](../../packages/sarisupply_design_system/test/goldens/brand.png)
- [Cashier sign-in](../../apps/pos/test/goldens/cashier.png)
- [Inventory and pending review](../../apps/pos/test/goldens/inventory.png)
- [Product form](../../apps/pos/test/goldens/product.png)
- [Management](../../apps/pos/test/goldens/management.png)
- [Admin review](../../apps/admin/test/goldens/admin_review.png)

## Verification and limits

Focused UI tests and the width/text-scaling fixture suites passed: 62 POS UI tests (61 in the combined run plus the subsequent missing-context recovery regression), 19 Admin tests, 13 Driver tests and 3 design-system tests. Architecture checks and formatting of the redesign source/test files passed. Scoped POS source/fixture analysis, Admin analysis, and design-system analysis passed. Admin release web, POS Development debug APK and Driver Development debug APK builds passed using the repository-supported commands.

`bash tool/verify_fast.sh`, `bash tool/verify_local.sh`, and `bash tool/verify_harness.sh` were attempted. Whole-workspace verification was interrupted by concurrent, unfinished checkout code/tests, including missing checkout-grant symbols and checkout lint/format failures. Those files were left untouched. A passing focused suite or direct build does not make the full harness pass.

Initial harness attempts stopped at static analysis in concurrent checkout work, including `checkout_store.dart`, `inventory_store.dart` and `firebase_pos_workflow.dart` (`curly_braces_in_flow_control_structures`). Earlier attempts also observed unfinished checkout models, inventory storage and grant tests. Phone-verification harness attempts stopped at formatting in concurrent checkout tests and source. The final attempt reported `packages/sarisupply_models/test/checkout_test.dart` and `apps/pos/lib/features/checkout/checkout_controller.dart`. Those changes remain untouched. The review was a separate author self-review; no independent reviewer was used. TalkBack/VoiceOver, full Admin browser keyboard navigation, live backend workflows and real-world speed improvements remain unverified. Screenshot appearance does not prove faster operation. No deployment was performed.

## Android phone follow-up

On 2026-10-05 the user connected model **2510DRA23G**, Android 15/API 35, 1080×2392 physical pixels at density 450 (about 384 logical pixels wide). Driver's actual Development APK rendered the shared identity and inactive state correctly. POS was updated in place without uninstalling or clearing its existing Development data.

The current concurrent backend implementation requires the build define `SARISUPPLY_API_URL`. No Development HTTPS origin was available. Hardware launch exposed an uncaught workflow-construction error; POS now displays the branded state “POS setup is incomplete. Contact your administrator.” The developer diagnostic remains reported. A widget regression covers safe startup failure; the existing sign-in fixture still passes. This is a presentation repair, not a replacement backend or an authorization bypass.

`apps/pos/integration_test/ui_device_test.dart` reuses the real screens and shared fixture data. Flutter's `integration_test` SDK package is a development-only dependency. Four hardware cases passed at the phone's normal text size and again with a 200% linear text override:

- Cashier manual/name switching, incorrect-PIN feedback, secret clearing and retained cashier ID.
- Saving a twelve-unit product with the physical keyboard open, preserving exact centavos and a leading-zero barcode; Save remains above the keyboard.
- Opening the phone management form and cancelling while the physical keyboard is open.
- Native SQLite inventory, physical-count context/cancellation and the visible Lock callback.

The suite uses fake repositories and an in-memory native SQLite database. It makes no backend calls or changes to the installed Development app's inventory or sessions. The previously absent base Android application ID was used solely for the debug integration-test install, keeping it separate from `.dev`; no production workflow or credentials were used. The test install is removed after evidence export. Android rejected shell writes to the system font-size setting, so 200% scaling was applied only inside the fixture app; the phone's setting remains 1.0.

Reproduce on a device with no existing base-package installation (otherwise use an isolated test device):

```bash
cd apps/pos
flutter test integration_test/ui_device_test.dart -d <device> --flavor prod --dart-define=SARISUPPLY_ENV=dev
flutter test integration_test/ui_device_test.dart -d <device> --flavor prod --dart-define=SARISUPPLY_ENV=dev --dart-define=SARISUPPLY_TEST_TEXT_SCALE=2
```

The commands run the fixture test entry point, not production `main.dart`. Hardware screenshots contain fixture data only; Flutter capture excludes the native keyboard, whose presence is asserted from actual platform insets. These checks establish on-device rendering and interactions for the listed cases. They do not establish live cashier login, device activation, synchronization, human comfort or faster task completion. Those require configured backend access and a separate user usability session.

The follow-up's 19 host startup/gate tests, scoped analysis, formatting and architecture checks passed. The repaired Development APK built and was installed with version code 2006; its safe configuration state was visually checked on the phone. The original installation date remained unchanged. No Development app data was cleared.

Retained hardware fixture captures:

- [Cashier at normal text size](screenshots/ui-phone/cashier-100.png)
- [Inventory at 200%](screenshots/ui-phone/inventory-200.png)
- [Twelve-unit product with keyboard insets at 200%](screenshots/ui-phone/product-keyboard-200.png)
- [Management form with keyboard insets at 200%](screenshots/ui-phone/management-keyboard-200.png)
- [Physical count at 200%](screenshots/ui-phone/count-200.png)
