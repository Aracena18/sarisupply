---
name: flutter-quality
description: Review Flutter/Dart changes in SariSupply for package boundaries, state/UI correctness, maintainability, tests, responsive behavior, and accidental visual changes.
---

# Flutter Quality

- Run formatting and analysis.
- Prefer shared packages over cross-application imports.
- Keep deterministic business policies out of widgets.
- Prefer pure Dart for domain logic that does not require Flutter.
- Check loading, empty, error, disabled, and success states when applicable.
- Check target form factors for UI changes.
- Do not change design language during infrastructure-only work.
- Add focused widget/unit tests for changed behavior.
- Reject hidden coupling between POS, Admin, and Driver applications.
