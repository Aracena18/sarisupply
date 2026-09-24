#!/usr/bin/env bash
set -euo pipefail

if [[ -f apps/pos/pubspec.yaml && -f apps/driver/pubspec.yaml && -f apps/admin/pubspec.yaml ]]; then
  echo "SariSupply Flutter foundation already exists; nothing to bootstrap."
  exit 0
fi

echo "==> Toolchain"
flutter --version
dart --version

echo "==> Creating Flutter applications and shared packages"
mkdir -p apps packages docs/architecture docs/superpowers/plans

flutter create   --org com.sarisupply   --project-name sarisupply_pos   --platforms=android   apps/pos

flutter create   --org com.sarisupply   --project-name sarisupply_driver   --platforms=android   apps/driver

flutter create   --org com.sarisupply   --project-name sarisupply_admin   --platforms=web   apps/admin

flutter create   --template=package   --project-name sarisupply_core   packages/sarisupply_core

flutter create   --template=package   --project-name sarisupply_models   packages/sarisupply_models

flutter create   --template=package   --project-name sarisupply_design_system   packages/sarisupply_design_system

echo "==> Root workspace configuration"
cat > pubspec.yaml <<'EOF_ROOT_PUBSPEC'
name: sarisupply_workspace
publish_to: none

environment:
  sdk: ">=3.3.0 <4.0.0"

dev_dependencies:
  melos: ^6.3.3
EOF_ROOT_PUBSPEC

cat > melos.yaml <<'EOF_MELOS'
name: sarisupply

packages:
  - apps/**
  - packages/**

command:
  bootstrap:
    runPubGetInParallel: false

scripts:
  format:
    run: melos exec --fail-fast -- "dart format --output=none --set-exit-if-changed lib test"
    description: Check Dart formatting in every package.

  analyze:
    run: melos exec --fail-fast -- "flutter analyze"
    description: Analyze every Flutter package.

  test:
    run: melos exec --fail-fast --dir-exists=test -- "flutter test"
    description: Run tests in every package with a test directory.

  verify:
    run: melos run format && melos run analyze && melos run test
    description: Run repository verification.
EOF_MELOS

cat > analysis_options.yaml <<'EOF_ANALYSIS'
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    avoid_print: true
    prefer_final_locals: true
EOF_ANALYSIS

for pkg in apps/pos apps/driver apps/admin packages/sarisupply_core packages/sarisupply_models packages/sarisupply_design_system; do
  cat > "$pkg/analysis_options.yaml" <<'EOF_CHILD_ANALYSIS'
include: ../../analysis_options.yaml
EOF_CHILD_ANALYSIS
done

echo "==> Installing Riverpod and local shared dependencies"
(
  cd apps/pos
  flutter pub add flutter_riverpod
  flutter pub add sarisupply_core --path=../../packages/sarisupply_core
  flutter pub add sarisupply_design_system --path=../../packages/sarisupply_design_system
)
(
  cd apps/driver
  flutter pub add flutter_riverpod
  flutter pub add sarisupply_core --path=../../packages/sarisupply_core
  flutter pub add sarisupply_design_system --path=../../packages/sarisupply_design_system
)
(
  cd apps/admin
  flutter pub add flutter_riverpod
  flutter pub add sarisupply_core --path=../../packages/sarisupply_core
  flutter pub add sarisupply_design_system --path=../../packages/sarisupply_design_system
)

echo "==> Shared core package"
rm -f packages/sarisupply_core/test/*_test.dart
mkdir -p packages/sarisupply_core/lib/src packages/sarisupply_core/test
cat > packages/sarisupply_core/test/app_identity_test.dart <<'EOF_CORE_TEST'
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_core/sarisupply_core.dart';

void main() {
  test('exposes stable application names', () {
    expect(AppIdentity.posName, 'SariSupply POS');
    expect(AppIdentity.driverName, 'SariSupply Driver');
    expect(AppIdentity.adminName, 'SariSupply Admin');
  });
}
EOF_CORE_TEST

# RED: the test above intentionally exists before production code.
if (cd packages/sarisupply_core && flutter test test/app_identity_test.dart); then
  echo "ERROR: AppIdentity test unexpectedly passed before implementation."
  exit 1
else
  echo "Expected RED confirmed for AppIdentity."
fi

cat > packages/sarisupply_core/lib/src/app_identity.dart <<'EOF_CORE_IMPL'
abstract final class AppIdentity {
  static const posName = 'SariSupply POS';
  static const driverName = 'SariSupply Driver';
  static const adminName = 'SariSupply Admin';
}
EOF_CORE_IMPL

cat > packages/sarisupply_core/lib/sarisupply_core.dart <<'EOF_CORE_EXPORT'
library sarisupply_core;

export 'src/app_identity.dart';
EOF_CORE_EXPORT

(cd packages/sarisupply_core && flutter test test/app_identity_test.dart)

echo "==> Shared models package"
rm -f packages/sarisupply_models/test/*_test.dart
mkdir -p packages/sarisupply_models/lib/src packages/sarisupply_models/test
cat > packages/sarisupply_models/test/money_test.dart <<'EOF_MONEY_TEST'
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  group('Money', () {
    test('adds values using integer centavos', () {
      const left = Money(1050);
      const right = Money(250);

      expect(left + right, const Money(1300));
    });

    test('rejects a negative amount when nonNegative is requested', () {
      expect(
        () => Money.nonNegative(-1),
        throwsArgumentError,
      );
    });
  });
}
EOF_MONEY_TEST

if (cd packages/sarisupply_models && flutter test test/money_test.dart); then
  echo "ERROR: Money test unexpectedly passed before implementation."
  exit 1
else
  echo "Expected RED confirmed for Money."
fi

cat > packages/sarisupply_models/lib/src/money.dart <<'EOF_MONEY_IMPL'
final class Money {
  const Money(this.centavos);

  factory Money.nonNegative(int centavos) {
    if (centavos < 0) {
      throw ArgumentError.value(
        centavos,
        'centavos',
        'must not be negative',
      );
    }
    return Money(centavos);
  }

  final int centavos;

  Money operator +(Money other) => Money(centavos + other.centavos);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money && other.centavos == centavos;

  @override
  int get hashCode => centavos.hashCode;
}
EOF_MONEY_IMPL

cat > packages/sarisupply_models/lib/sarisupply_models.dart <<'EOF_MONEY_EXPORT'
library sarisupply_models;

export 'src/money.dart';
EOF_MONEY_EXPORT

(cd packages/sarisupply_models && flutter test test/money_test.dart)

echo "==> Shared design system package"
rm -f packages/sarisupply_design_system/test/*_test.dart
mkdir -p packages/sarisupply_design_system/lib/src/theme packages/sarisupply_design_system/test
cat > packages/sarisupply_design_system/test/sarisupply_theme_test.dart <<'EOF_THEME_TEST'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
  test('creates a Material 3 light theme', () {
    final theme = SariSupplyTheme.light();

    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.light);
  });
}
EOF_THEME_TEST

if (cd packages/sarisupply_design_system && flutter test test/sarisupply_theme_test.dart); then
  echo "ERROR: theme test unexpectedly passed before implementation."
  exit 1
else
  echo "Expected RED confirmed for shared theme."
fi

cat > packages/sarisupply_design_system/lib/src/theme/sarisupply_theme.dart <<'EOF_THEME_IMPL'
import 'package:flutter/material.dart';

abstract final class SariSupplyTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }
}
EOF_THEME_IMPL

cat > packages/sarisupply_design_system/lib/sarisupply_design_system.dart <<'EOF_THEME_EXPORT'
library sarisupply_design_system;

export 'src/theme/sarisupply_theme.dart';
EOF_THEME_EXPORT

(cd packages/sarisupply_design_system && flutter test test/sarisupply_theme_test.dart)

echo "==> POS Flutter shell"
cat > apps/pos/test/widget_test.dart <<'EOF_POS_TEST'
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/main.dart';

void main() {
  testWidgets('shows the POS application identity', (tester) async {
    await tester.pumpWidget(const SariSupplyPosApp());

    expect(find.text('SariSupply POS'), findsOneWidget);
    expect(find.text('Foundation ready'), findsOneWidget);
  });
}
EOF_POS_TEST

cat > apps/pos/lib/main.dart <<'EOF_POS_MAIN'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
  runApp(const ProviderScope(child: SariSupplyPosApp()));
}

class SariSupplyPosApp extends StatelessWidget {
  const SariSupplyPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppIdentity.posName,
      theme: SariSupplyTheme.light(),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppIdentity.posName),
              Text('Foundation ready'),
            ],
          ),
        ),
      ),
    );
  }
}
EOF_POS_MAIN

(cd apps/pos && flutter test test/widget_test.dart)

echo "==> Driver Flutter shell"
cat > apps/driver/test/widget_test.dart <<'EOF_DRIVER_TEST'
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_driver/main.dart';

void main() {
  testWidgets('shows the Driver application identity', (tester) async {
    await tester.pumpWidget(const SariSupplyDriverApp());

    expect(find.text('SariSupply Driver'), findsOneWidget);
    expect(find.text('Foundation ready'), findsOneWidget);
  });
}
EOF_DRIVER_TEST

cat > apps/driver/lib/main.dart <<'EOF_DRIVER_MAIN'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
  runApp(const ProviderScope(child: SariSupplyDriverApp()));
}

class SariSupplyDriverApp extends StatelessWidget {
  const SariSupplyDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppIdentity.driverName,
      theme: SariSupplyTheme.light(),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppIdentity.driverName),
              Text('Foundation ready'),
            ],
          ),
        ),
      ),
    );
  }
}
EOF_DRIVER_MAIN

(cd apps/driver && flutter test test/widget_test.dart)

echo "==> Admin Flutter Web shell"
cat > apps/admin/test/widget_test.dart <<'EOF_ADMIN_TEST'
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_admin/main.dart';

void main() {
  testWidgets('shows the Admin application identity', (tester) async {
    await tester.pumpWidget(const SariSupplyAdminApp());

    expect(find.text('SariSupply Admin'), findsOneWidget);
    expect(find.text('Foundation ready'), findsOneWidget);
  });
}
EOF_ADMIN_TEST

cat > apps/admin/lib/main.dart <<'EOF_ADMIN_MAIN'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
  runApp(const ProviderScope(child: SariSupplyAdminApp()));
}

class SariSupplyAdminApp extends StatelessWidget {
  const SariSupplyAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppIdentity.adminName,
      theme: SariSupplyTheme.light(),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppIdentity.adminName),
              Text('Foundation ready'),
            ],
          ),
        ),
      ),
    );
  }
}
EOF_ADMIN_MAIN

(cd apps/admin && flutter test test/widget_test.dart)

echo "==> Architecture documentation"
cat > docs/architecture/SARI_SUPPLY_PRODUCTION_PLAN.md <<'EOF_ARCH'
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
- Firebase Storage, FCM, App Check, Crashlytics
- Drift/SQLite later for durable offline POS transactions and local projections

## Confirmed production capabilities

The approved roadmap includes multi-device and multi-branch POS, cashier PIN switching, product catalog and suggested pricing, multi-unit inventory, inventory ledger, offline synchronization, controlled negative inventory reconciliation, stock counts, batches and expiry, cash shifts, optional printing, Scan-to-Pay, refunds and voids, customer credit/utang, smart restocking with owner approval, multi-warehouse inventory, procurement, fulfillment, hybrid delivery, separate Flutter driver app, Flutter Web admin, promotions, reporting, and tax-ready internal receipts.

## Engineering direction

The repository is a Melos-managed Flutter/Dart monorepo using Riverpod and feature-first application architecture. Shared code lives in focused packages. Applications never import one another directly.

Implementation proceeds vertically, starting with a reliable Flutter foundation, then identity/tenant/device setup, then offline POS and sync before operational warehouse and delivery features.
EOF_ARCH

cat > docs/superpowers/plans/2026-09-25-sarisupply-foundation.md <<'EOF_PLAN'
# SariSupply Foundation Implementation Plan

## Goal

Create a GitHub-backed Flutter/Dart monorepo in which the POS, Driver, and Admin applications compile independently, reuse focused shared packages, and are verified through GitHub Actions.

## Foundation deliverables

1. Flutter POS Android application
2. Flutter Driver Android application
3. Flutter Admin Web application
4. Melos workspace
5. Riverpod in all three applications
6. Shared core, models, and design-system packages
7. Test-first shared primitives
8. Repository-wide format, analyze, and test commands
9. GitHub Actions CI
10. Android and Flutter Web build verification
11. Secret hygiene before Firebase integration

## Next milestone

Firebase + Google Sign-In + Merchant + Branch + Device + Owner/Manager + Cashier PIN foundation.
EOF_PLAN

echo "==> Continuous integration workflow"
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'EOF_CI'
name: CI

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  verify:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Toolchain
        run: |
          flutter --version
          dart --version

      - name: Install workspace dependencies
        run: |
          dart pub get
          dart run melos bootstrap

      - name: Verify formatting, analysis, and tests
        run: dart run melos run verify

      - name: Build Admin Web
        working-directory: apps/admin
        run: flutter build web --release

      - name: Build POS Android debug APK
        working-directory: apps/pos
        run: flutter build apk --debug

      - name: Build Driver Android debug APK
        working-directory: apps/driver
        run: flutter build apk --debug
EOF_CI

echo "==> Root README update"
cat > README.md <<'EOF_README'
# SariSupply

SariSupply is an offline-first retail operating system and distribution platform for medium-sized sari-sari stores.

## Flutter applications

Every user-facing application is built with **Flutter**:

- `apps/pos` — SariSupply POS for Android tablets/mobile devices
- `apps/driver` — SariSupply Driver for Android
- `apps/admin` — SariSupply Admin / Operations for Flutter Web

## Shared packages

- `packages/sarisupply_core` — shared application primitives
- `packages/sarisupply_models` — shared domain value objects
- `packages/sarisupply_design_system` — shared Flutter theming

Applications must not import one another directly.

## Backend direction

Firebase will provide Authentication, Firestore, Cloud Functions, Storage, FCM, App Check, Crashlytics, and supporting cloud services. The POS will later use Drift/SQLite for durable offline-first operation.

## Workspace

The repository is managed with Melos.

```bash
dart pub get
dart run melos bootstrap
dart run melos run verify
```

## Build targets

```bash
cd apps/pos && flutter build apk --debug
cd apps/driver && flutter build apk --debug
cd apps/admin && flutter build web --release
```

## Documentation

- `docs/architecture/SARI_SUPPLY_PRODUCTION_PLAN.md`
- `docs/superpowers/plans/2026-09-25-sarisupply-foundation.md`
EOF_README

echo "==> Workspace bootstrap"
dart pub get
dart run melos bootstrap

echo "==> Format generated and authored Dart code"
dart run melos exec -- "dart format lib test"

echo "==> Full verification"
dart run melos run verify

echo "==> Platform builds"
(
  cd apps/admin
  flutter build web --release
)
(
  cd apps/pos
  flutter build apk --debug
)
(
  cd apps/driver
  flutter build apk --debug
)

echo "SariSupply Flutter foundation bootstrapped successfully."
