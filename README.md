# SariSupply

SariSupply is an offline-first retail operating system and distribution platform for medium-sized sari-sari stores.

## Flutter applications

All user-facing applications in this project are built with **Flutter**:

- `apps/pos` — SariSupply POS for Android tablets/mobile devices
- `apps/driver` — SariSupply Driver for Android
- `apps/admin` — SariSupply Admin / Operations for Flutter Web

## Backend

Firebase will provide cloud infrastructure for authentication, Firestore, Cloud Functions, Storage, notifications, App Check, and monitoring. The POS will later use Drift/SQLite for durable offline-first operation.

## Architecture

This repository is a Flutter/Dart monorepo. Shared code belongs in `packages/`; applications must not import one another directly.

The first milestone establishes the repository, Flutter workspace, shared packages, Riverpod foundation, tests, and continuous integration before business features are added.
