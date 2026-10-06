# SariSupply Design System v1

A local Flutter design-system package Codex can copy into the SariSupply repository and use directly.

## Brand direction

**Warm Utility** — reliable, modern, warm, premium without looking luxurious, and operational enough for real sari-sari store workflows.

Core visual formula:

- warm paper backgrounds
- white functional surfaces
- strong warm-black typography
- orange used selectively as energy / action
- minimal borders instead of excessive shadows
- logo-derived slats, cuts, supply line, and modular shelf geometry
- consistent 8pt spacing rhythm
- one icon language

## Install in the SariSupply monorepo

Copy this entire folder to:

`packages/sarisupply_design_system/`

Then add to each Flutter app:

```yaml
dependencies:
  sarisupply_design_system:
    path: ../../packages/sarisupply_design_system
```

Path depth may need adjustment depending on the app location.

Use:

```dart
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

MaterialApp(
  theme: SariSupplyTheme.light,
  darkTheme: SariSupplyTheme.dark,
);
```

## Instrument Sans

The system is authored for **Instrument Sans**.

Font binaries are intentionally **not included** in this package. Add properly licensed Instrument Sans font assets to the host app and register the family name as `InstrumentSans`.

Until the asset is installed, the system falls back to Inter / Roboto / Arial.

Recommended host-app registration:

```yaml
flutter:
  fonts:
    - family: InstrumentSans
      fonts:
        - asset: assets/fonts/InstrumentSans-VariableFont_wdth,wght.ttf
```

## Approved logo

- `assets/brand/sarisupply_logo.svg`
- `assets/brand/sarisupply_symbol.svg`

Do not redraw, stretch, skew, add gradients, or alter internal proportions.

## Primary UI rules

1. Default page background: `Paper #FFFDF9`
2. Default card: white with 1px `#E9E4DE` border
3. Standard card radius: `12px`
4. Standard horizontal mobile padding: `16px`
5. Section spacing: `24px`
6. Primary bright orange: `#F26A1B`
7. Put **Ink #111111** text on bright orange.
8. Use `#C84A00` when white text on orange is required.
9. Default cards have **no shadow**.
10. Shadows are reserved for overlays, menus, dialogs, and sheets.

## Assets

### Brand elements
- `slats_pattern.svg`
- `supply_line.svg`
- `card_cut.svg`
- `module_shapes.svg`
- `shelf_grid.svg`

### Custom icons
- POS
- Products
- Inventory
- Restock
- Orders
- Suppliers
- Driver
- Branches
- Analytics
- Cashier

## Avoid AI-slop UI

Do **not** introduce:
- random blue/purple gradients
- glassmorphism as a default component style
- floating-card-everything layouts
- inconsistent corner radii
- excessive shadows
- arbitrary decorative blobs
- mixed outline / filled / 3D icon families
- full orange dashboard backgrounds
- random spacing outside the token scale
- giant marketing-style headings inside operational screens

Read `docs/AI_SLOP_GUARDRAILS.md` before redesigning screens.
