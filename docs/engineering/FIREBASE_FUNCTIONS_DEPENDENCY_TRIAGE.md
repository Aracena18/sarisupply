# Firebase Functions dependency triage

**Reviewed:** 2026-10-03
**Status:** Findings assessed; two advisory chains temporarily accepted pending upstream updates.

## Snapshot

The audit was run in `firebase/functions` with Node 22.22.1 and npm 10.9.4:

```text
npm audit             7 affected-package entries: 5 high, 2 moderate
npm audit --omit=dev  2 affected-package entries: 2 moderate, 0 high
npm outdated          @types/node and vitest have patch updates available
```

The count is npm's package-level aggregation, not seven independent vulnerability mechanisms. The full report is saved locally at `/tmp/sarisupply-npm-audit.json` and is not a repository artifact.

## Findings and disposition

| Advisory | Dependency path and scope | Reachability assessment | Disposition |
| --- | --- | --- | --- |
| [GHSA-m9gg-hp2v-232j](https://github.com/advisories/GHSA-m9gg-hp2v-232j), high | `@firebase/rules-unit-testing@5.0.2` (direct `devDependency`) → `firebase@12.19.0` → `@firebase/firestore@4.17.2` → `@grpc/grpc-js@1.9.16`. The five high audit entries are this advisory propagated through that dependency chain. The chain is absent from `npm audit --omit=dev`. | The advisory concerns server-side client-certificate authorization configurations. SariSupply uses this package for emulator tests; Functions source does not create a gRPC server or use xDS. Firebase's Node.js build environment installs production dependencies by default, so the dev-only test chain is not part of the deployed Functions dependency set. | Temporarily accept as local/emulator test tooling. Do not take the suggested forced downgrade: npm proposes `@firebase/rules-unit-testing@2.0.7`, whose peer requirement is `firebase@^9.0.0`, while this project uses Firebase 12 and rules-unit-testing 5.0.2. Reassess when the testing SDK or its Firestore/gRPC dependency publishes a compatible fix. |
| [GHSA-f596-whhp-79r4](https://github.com/advisories/GHSA-f596-whhp-79r4), low | A second advisory on the same dev-only `@grpc/grpc-js@1.9.16` node. It does not add a separate high-severity package chain. | The issue concerns gRPC server handlers returning sensitive error text. SariSupply Functions source does not host gRPC handlers. | Covered by the same temporary dev-tooling acceptance. Reassess with the high advisory. |
| [GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq), moderate | `firebase-admin@14.5.0` → optional `@google-cloud/storage@8.2.0` → `gaxios@6.7.1` → `uuid@9.0.1`. npm reports two moderate affected-package entries (`gaxios` and `uuid`); this is one advisory chain in the production dependency graph. | The advisory affects UUID v3/v5/v6 calls that write to caller-provided buffers with invalid bounds. The Functions source has no `uuid` imports/calls or Cloud Storage API use. The installed gaxios package declares `uuid` but contains no runtime UUID import/use. Thus the package is in the production dependency tree, but the vulnerable API path is not reachable through current Functions code. | Temporarily accept pending a compatible upstream update to the Storage/gaxios chain. Reassess before adding UUID or Cloud Storage use to Functions, and when the parent packages publish compatible updates. |

The two gRPC advisories are fixed upstream in `@grpc/grpc-js` 1.13.6 and 1.14.5. The production Firebase Admin paths already resolve gRPC 1.14.5; only the test peer path resolves 1.9.16. The current Firestore test dependency constrains that peer to `~1.9.0`, so a forced override would cross its declared range and needs its own compatibility review.

The `uuid` advisory's upstream fixed release is 11.1.1. The installed gaxios 6.7.1 dependency range is `uuid@^9.0.1`; the published gaxios 6.x line currently ends at 6.7.1. `npm audit fix --dry-run` did not remove the findings. No dependency manifest or lockfile was changed during triage.

## Follow-up gates

- Re-run `npm audit`, `npm audit --omit=dev`, and `npm audit --json` when Firebase Functions dependencies change and before the next backend milestone is accepted.
- Resolve the gRPC test dependency chain with a compatible upstream release or an explicitly tested dependency override; do not downgrade the emulator test SDK to its Firebase 9 peer line.
- Resolve the UUID chain when a compatible Storage/gaxios release includes a fixed UUID version. Resolve it before adding UUID buffer APIs or Cloud Storage operations to Functions.
- Keep the JSON audit snapshot in `/tmp`; do not commit machine-specific audit output.

## References

- [Firebase Functions dependency handling](https://firebase.google.com/docs/functions/handle-dependencies)
- [Google Cloud Functions Node.js dependency installation](https://docs.cloud.google.com/run/docs/runtimes/nodejs-dependencies)
