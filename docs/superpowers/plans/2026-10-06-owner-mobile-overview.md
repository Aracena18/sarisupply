# Owner mobile overview and management navigation

## Goal

Give Store Owners a phone-first home for today's locally recorded sales and
branch stock alerts, and make store-management destinations visible without
scrolling a category dropdown.

## Scope

- Add a branch-aware Owner overview using existing local inventory and checkout
  reads: daily net sales, transaction count, low-stock products (the current
  Restock Orders threshold, ten units), and direct links to sales and stock.
- Show a clear local-data freshness/coverage note so one device's offline ledger
  is not presented as an organization-wide total.
- Replace the phone category dropdown with persistent Overview, Branches, Team,
  and Devices navigation. Give Team visible Cashiers, Managers, and Invitations
  subtabs, filtered by the existing membership role.
- Keep wide-screen side navigation and existing management actions.

## Invariants and limits

Presentation-only. Keep repositories, authorization checks, cashier PIN handling,
operation identity, SQLite data, sync behavior, and server contracts unchanged.
Do not claim cross-device sales aggregation; use only the current branch's local
database and label it accordingly. Do not add new dependencies.

## Verification

Update focused navigation/dashboard coverage, run POS analysis and fast checks,
and inspect the phone-width layout. Full production acceptance remains a separate
gate.
