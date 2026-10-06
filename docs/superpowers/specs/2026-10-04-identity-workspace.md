# Phase 2: practical identity workspace

The user instructed proceeding with Phase 2 after the local Phase 1 checks passed.
This authorizes local implementation while hosted feasibility remains pending;
it does not certify hosting or authorize paid services or a pilot.

Existing Flutter identity flows gain a paginated management workspace. Owners
manage branches, invitations, managers, cashiers and devices. Managers see only
authorized branches, their devices and cashiers whose complete assignment is in
scope; existing server policies govern all mutations. No Firestore read rule is
opened. A bounded HTTPS list endpoint projects safe public fields and never reads
cashier credentials. Pages scan at most 50 records; filtered empty pages can still
have a continuation cursor. Owners see inactive records for recovery.

Management can be opened before activation or from the cashier lock screen via
human Google sign-in. Returning signs out the management human session without
clearing the device session. Destructive changes require a concise confirmation.
Temporary PINs appear only in a dismissible dialog; never persist or log them.
Cashier creation supplies a stable operation ID as document ID. A repeat cannot
create a duplicate or persist/replay plaintext PIN; it directs the operator to PIN
reset. Device activation and Admin review retain IDs after uncertain failures.

Cashier sign-in offers names and employee codes from a current device-scoped
bundle; unavailable roster keeps explicit ID entry usable, including offline.
Selecting a name never authorizes login; PIN and existing offline policy do that.
No metadata cache extends the seven-day window. Secrets clear from fields after
attempts; async callbacks do not touch disposed widgets.

Use shared Material 3 page constraints and concise, actionable errors. Forms
disable submissions/inputs while pending, preserve entries on failure and support
keyboard, scrolling, phone/tablet widths and larger text. Admin queue supports
search and useful business/address information rather than applicant IDs.

Tests must cover cross-tenant/branch/role reads, revoked membership, pagination,
secret exclusion, duplicate creation, retries, input validation, confirmations,
roster fallback, safe errors and small/large layouts. Full harness and one fresh
independent review precede reporting local completion. Live hardware/hosting and
all later platform milestones remain outstanding.
