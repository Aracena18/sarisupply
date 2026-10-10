# Driver UI/UX review and refinement — 2026-10-07

## Design judgment

Driver is a phone tool used between deliveries. Its interface should answer three
questions quickly: which workspace am I using, where is my next stop, and what do
I do next? Preserve SariSupply's Warm Utility identity, Instrument Sans, warm
paper, white working surfaces, orange actions and native task navigation.

The review used the installed Driver Dev workspace screen and rendered Flutter
route/stop screens with sample assignments. Those previews establish presentation,
not live order, payment or delivery acceptance.

| Finding | Improvement |
| --- | --- |
| Large entry branding pushes workspace choices down; operational roles compete with rider access. | Compact signed-in identity, clear workspace heading, rider cards first, other roles in a secondary expandable group. Sign-in keeps the shared brand. |
| Route context and the next destination have similar emphasis. | Quiet assigned-route summary above a focused white next-stop card with full-width destination/address and quantity/payment context. |
| Repeated bold labels, dividers and large summaries compete for attention. | Shared type scale, softer weights, consistent spacing and a quieter delivery-summary surface. |
| White text on brand orange has only 3.06:1 contrast. | Ink text has 6.16:1 contrast on the same orange. Labels and icons inherit disabled button styling. |
| The step sequence is implicit, and progress calls recorded proof “delivered.” | A stage cue derives from saved progress, omitting optional stages. Route progress says “stops recorded”; partial delivery and waiting-to-sync labels remain explicit. |
| Upcoming previews show a navigation arrow despite having no action, and only two upcoming stops are shown. | Remove inactive arrows and show all remaining loaded stops. Keep View stop details as the actual entry to the next stop. |
| Contact details are difficult to find alongside delivery work. | Expandable Contact & instructions section, including selectable contact phone text from the assigned stop. |

## Scope and invariants

Changes are presentation only. Company rider route/detail views, signed-in Driver
workspace selection and legacy Driver action contrast changed. Sign-in, company
selection, invitation authority, access-cache expiry, backend authorization, money
calculations, delivery transitions and durable draft/proof writes retain their
existing implementation. No new package dependency, cloud change or data reset.

The accepted presentation is recorded in `design.md`. State/money/persistence
methods were checked against a private pre-change source snapshot. Existing route
tests were aligned with the current guided flow and asynchronous rendering.

## Verification

- Driver and company-package static analysis: zero issues.
- Formatting and architecture boundary checks pass.
- Nine focused checks cover rider selection, secondary company roles, invitation
  acceptance, loading restrictions, assigned stop order, denied actions, pending
  partial proof, empty route recovery and QR's omission of cash collection.
- Phone layout checks cover 390px at normal text and 320px at 200% text, including
  directions, arrival, item confirmation, cash collection and recipient proof.
- Actual widgets were rendered with the bundled fonts for visual inspection of
  workspace selection, route and stop detail.

The full fast-verification script, full harness and emulator suites are deferred
under the repository's presentation build instructions. Manual delivery acceptance
and on-road usability remain user checks; this refinement is not production
acceptance.

## Development phone update

The repository build script produced the Driver Dev debug APK with the existing
Development environment/API settings. The installed package, signing certificate
and non-decreasing version code were checked before `adb install -r`; Android
reported Success. Cold launch succeeded. The compact signed-in workspace screen
loaded the existing rider warehouse assignment and secondary company role.
No uninstall or data clear was used; the original installation timestamp remains.
Live route interaction still requires the user's manual check because the phone
rejects injected touch events.
