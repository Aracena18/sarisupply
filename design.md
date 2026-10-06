# SariSupply design contract

Read this before changing UI, UX, or user-facing copy. Update it when an accepted design decision changes.

## Identity

Playful local retail: one simple storefront with a mango awning and teal body, one SariSupply wordmark, and POS, Admin, or Driver as the role label. The bundled storefront asset is shared with launcher and web icons. No Flutter scaffold branding or development status in product screens.

Primary `#00796B`; mango accent `#FFCA58`; page background `#FAFAF7`; primary text `#173C36`. Mango is decorative, not a warning. Errors use the Material error palette; offline and review states always have text, not color alone.

Locally bundled Nunito Sans 400/600/700, under the [SIL Open Font License](packages/sarisupply_design_system/assets/fonts/OFL.txt). Body/input 16, supporting text 14, task title 20, entry wordmark 24 logical pixels. Respect system text scaling; never shrink text to fit.

## Layout and components

Material 3; Material icons, normally 24 logical pixels. Buttons and inputs have 12-pixel radii; grouped surfaces 16. Use the shared 4/8/12/16/24/32 spacing scale. Page padding is 16 below 600 logical pixels, 24 above. Constrain reading width on larger screens.

One task title, then context, then the task, then recovery/status. Verb-led actions; no repeated instructions, promotional filler, or empty dashboards. Preserve units, validation, offline status, and consequences. Native task navigation; no placeholder tabs.

Forms occupy a full page below 600 logical pixels and a constrained dialog above. One scroll area for form content; actions remain reachable with the keyboard open. Preserve form controllers, draft/operation IDs, and non-secret selections during width changes. Secret values clear on failed authentication and dismissal.

Management uses a category selector on phones and side navigation on wide screens. One contextual creation action. Cashier sign-in opens phone Checkout after access verification; Lock returns to cashier selection and disposes Checkout without deleting local business data. Automatically open the only authorized stock branch when only one store is available; multiple stores or branches require an explicit choice.

## States and accessibility

Distinguish loading, empty, no matches, error, pending submission, saved locally, sync pending, and needs review. Synchronization errors retain inventory and pending work. Pending counts remain reachable from the status summary. Exact barcode matches display the matched unit and its exact price. Retry preserves operation IDs. Confirm destructive actions and Admin review decisions with their consequences.

Minimum 48×48 tap targets, readable contrast, labeled controls, keyboard access, and 200% text scaling. Follow [Flutter’s accessibility checklist](https://docs.flutter.dev/ui/accessibility). Test 320, 390, 600, 1024, and 1280 widths; test device usability separately from screenshots.

## Approved examples

- Entry: storefront / SariSupply / POS / “Sign in with Google”.
- Incomplete POS startup configuration: shared identity / “POS setup is incomplete. Contact your administrator.” Do not offer retry for missing build configuration.
- Cashier: “Cashier sign in” / name or cashier ID / PIN / “Sign in”; roster errors offer “Retry names”.
- Inventory: branch / search / filters / sync status / product name, stock in base units, base price. Expand for sale units and authorized actions.
- Count: “Physical count” / product, current stock, base unit / entered quantity / reason / “Save count”. Success: “Saved locally · Sync pending”.
- Admin: “Review application” / business and branch summary / rejection reason / “Approve” or “Reject”, followed by confirmation.
- Driver: shared identity / “No delivery workspace available”; no fake delivery actions.

## Future scope

Checkout is the cashier’s primary task: local shifts, search/rear-camera barcode scanning, saved carts, cash/manual QR and immutable receipts. Driver stops and delivery actions remain a future milestone. Dark mode, localization, and backend enrichment of invitation store names remain separate work. Invitations retain an identifiable store reference until the API supplies names.
