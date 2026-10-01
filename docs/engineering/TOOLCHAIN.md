# Supported Toolchain

SariSupply repository verification is pinned to the toolchain used to generate the current Flutter foundation.

## Required versions

- Flutter: **3.44.9 stable**
- Dart: **3.12.2**
- Firebase Functions: **Node.js 22** when the Firebase workspace is present

The Flutter revision recorded in the application metadata is:

```text
6b182d2c7585eba26d4edce0f97630effd256c33
```

## Why versions are enforced

Agentic development is sensitive to toolchain drift. Different Flutter versions may regenerate Android/Web scaffolding, formatting, analyzer behavior, or dependency resolution differently.

The goal is:

```text
same commit + same toolchain -> reproducible verification behavior
```

## Check

Run:

```bash
bash tool/check_toolchain.sh
```

The bootstrap and verification entry points invoke this check automatically.

Changing the supported toolchain is an explicit engineering change. Update this document, the checker, and verify the full repository before accepting a version change.
