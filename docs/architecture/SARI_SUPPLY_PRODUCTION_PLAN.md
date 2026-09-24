# SariSupply Production Architecture

## Product direction

SariSupply is a production-oriented retail operating system and distribution platform for medium-sized sari-sari stores. The POS is the operational entry point; the recurring business model is supplying and delivering store inventory.

## Flutter-only client strategy

All user-facing applications are implemented in Flutter:

- SariSupply POS — Flutter Android/tablet, offline-first
- SariSupply Driver — Flutter Android
- SariSupply Admin / Operations — Flutter Web

No React, Next.js, or separate non-Flutter frontend is part of the approved architecture.

## Backend and local data

- Firebase Authentication with Google Sign-In for Owner/Manager and administrative accounts
- Cloud Firestore as cloud source of truth
- Cloud Functions for privileged server-side logic
- Firebase Storage, FCM, App Check, and Crashlytics
- Drift/SQLite for durable offline POS transactions and local projections

## Confirmed production capabilities

The roadmap includes multi-device and multi-branch POS, cashier PIN switching, product catalog and suggested pricing, multi-unit inventory, inventory ledger, offline synchronization, controlled negative inventory reconciliation, stock counts, batches and expiry, cash shifts, optional printing, Scan-to-Pay, refunds and voids, customer credit/utang, smart restocking with owner approval, multi-warehouse inventory, procurement, fulfillment, hybrid delivery, separate Flutter Driver app, Flutter Web Admin, promotions, reporting, and tax-ready internal receipts.

## Engineering direction

The repository is a Melos-managed Flutter/Dart monorepo using Riverpod and feature-first architecture. Shared code lives in focused packages. Applications never import one another directly.

Implementation proceeds vertically: foundation, identity/tenant/device setup, offline POS and synchronization, then warehouse, fulfillment, delivery, and reporting.
