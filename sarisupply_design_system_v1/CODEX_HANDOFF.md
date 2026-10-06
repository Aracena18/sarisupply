# CODEX HANDOFF — SariSupply Design System v1

You are implementing UI in the existing SariSupply Flutter repository.

## Source of truth

Use this package as the visual source of truth:

`packages/sarisupply_design_system`

Do not invent replacement colors, radii, spacing values, shadows, or typography unless an existing product constraint makes it necessary.

## Required implementation behavior

1. Import `sarisupply_design_system.dart`.
2. Set `SariSupplyTheme.light` as the app light theme.
3. Prefer package components before creating local one-off widgets.
4. Build operational screens on `SariSupplyColors.paper`.
5. Use white cards with subtle borders; avoid card soup.
6. Use orange only for primary actions, selection, short emphasis, and brand moments.
7. Use semantic colors only for state meaning.
8. Use `SariSupplyTypography.moneyLarge` or tabular figures for monetary totals.
9. Maintain minimum 48px touch targets.
10. Use the 8pt-based spacing tokens.
11. Use `SariSupplyIcon` for core product navigation.
12. Decorative brand elements must come from `assets/elements/`.

## Screen recipe

Recommended mobile screen hierarchy:

- `Scaffold(backgroundColor: SariSupplyColors.paper)`
- top-level horizontal padding: `16`
- screen title
- optional helper copy
- 24px gap
- primary operational content
- 24px between major sections
- 12px between closely related components
- bottom navigation / sticky CTA where needed

## Visual hierarchy

Primary:
- task title
- money / quantity / critical state
- primary action

Secondary:
- metadata
- supporting text
- secondary action

Muted:
- captions
- timestamps
- helper copy

Never make every element orange.

## Accessibility

- Bright orange `#F26A1B`: use dark `#111111` foreground.
- Deep orange `#C84A00`: white foreground is allowed.
- Do not encode status with color alone.
- Preserve clear focus states and text labels.
- Minimum touch target: 48×48.

## When redesigning an existing screen

Before changing UI:
1. preserve all current functionality and state handling;
2. identify the screen's primary user task;
3. remove redundant visual containers;
4. map all styling to design-system tokens;
5. replace inconsistent icons;
6. test 320px-wide screens and text scaling;
7. verify offline/error/loading/empty states;
8. do not modify domain logic while styling unless required.

## Do not

- add gradients just to make the UI "premium";
- add glass cards;
- use arbitrary `BorderRadius.circular(...)` values;
- use raw hex colors in feature widgets;
- use `Colors.grey` for product UI;
- add decorative imagery to dense POS flows;
- hide operational data behind unnecessary animations.

If a new primitive is genuinely needed, add it to the design-system package first, then use it from product screens.
