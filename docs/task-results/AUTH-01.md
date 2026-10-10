# AUTH-01 handoff

Date: 2026-10-06. Task: [AUTH-01](../../SARI_SUPPLY_TASKS.md#auth-01).
Author: explicitly selected `gpt-6.1-sol`, reasoning `high` before authoring.
Independent reviewer: `/root/auth01_review`, separate `gpt-6.1-sol`, reasoning
`high`; both documents approved with no unresolved findings.
Parent orchestration model/settings unchanged.
Status: scoped documentation verification passed; independent review complete.
Coordinator integration/checklist update pending; no production acceptance claim.

## Goal and scope

Freeze company versus store principals, current role/warehouse/branch authority,
invitations, resource ownership, typed workspace responses, audit attribution,
actor/action denials and additive old-client compatibility. Published draft:
[authorization contract](../task-contracts/authorization.md).
Dependencies are **None**, confirmed against the selected card and checklist;
there are no direct prerequisite reviewed handoffs to integrate.

Only these two planned documents are written:

- `docs/task-contracts/authorization.md`
- `docs/task-results/AUTH-01.md`

No runtime, UI, existing specification, architecture, coordinator checklist,
dependency, credentials, provider, schema registry or data migration edits.
No reviewed baseline commit was supplied; working-tree draft is not an integrated
prerequisite for another task. Parent coordinates review/integration separately.

## Reuse, replaced assumptions and evidence

The [contract evidence table](../task-contracts/authorization.md#9-source-evidence-and-downstream-wiring)
links actual inspected sources and separates reused behavior from implementation
gaps. Existing merchant identity is retained as Store Owner/Manager identity;
device UID, cashier identity, grants, branch scope, temporary-PIN policy and
same-boot seven-day recovery stay separate and unchanged. Existing invitation
transactions/email/expiry patterns, checkout payload fingerprints, immutable
results, HTTPS command transport and deny-by-default rules are reuse candidates.

Superseded assumptions are merchant Owner equals Company Owner, merchant Manager
equals warehouse Operations, copied UID enrollment equals company invitation,
same-merchant branch delivery equals independent-store delivery, and Platform
Admin authority grants detailed retail reports. The draft replaces those
assumptions with separate company authority and explicit reviewed legacy bindings;
it does not claim the current runtime has changed.

Current `runIdempotent` caches key/result without a payload digest and returns
cached results before the handler's current checks. Existing accepted Manager
invitation replay precedes the merchant active check. These are target-contract
gaps, not proof that the new replay requirements already pass. Current checkout
does check its cashier grant before fingerprint/replay handling. Current Driver
denial removes assignment cache; durable business work must remain separate.

Read required AGENTS/canonical architecture first; then selected task/shared
rules, relevant CURRENT_STATE, compatible identity/free-platform specifications,
definition of done and scoped source evidence. Applied repository review-change,
firebase-security-review, offline-first-review and finish-task checklists.
Read caveman for concise updates; persisted documents retain full precise prose.
AUTH-01's explicit documentation-only checks supersede skill harness defaults.

## Contract assumptions and shared wiring

The proposed `authorizationVersion: 1`, logical company roots, invitation
uniqueness metadata and legacy bindings require coordinator version/path/index
reservation before runtime edits. They do not allocate deployed or SQLite schema
versions. Keep old `merchantId`, role values, command names and wire responses.
New company entry is additive and versioned, not an overload of merchant authority.
Owner provisioning remains trusted tooling, never a public self-elevation route.

AUTH-02 owns company identity/entry; AUTH-03/04 separate platform/store entry;
AUTH-05/06 wait for integrated owner and warehouse setup before invitations;
AUTH-07–12 preserve store credentials and enforce scope/removal; AUTH-13 closes
the observed broad platform reads; AUTH-14/90 cover UX/integration. Later business
contracts and RELEASE own explicit legacy adapters/migration rehearsal. No later
task executed. Coordinator owns shared command/export/gate/migration wiring.

## Verification

All commands run from `/home/robert_jhon/My_Codes_2/sarisupply`.
Initial baseline captured with `git status --short` and a Python snapshot of
modified/untracked file hashes: **167 preexisting files**, before either output
document existed. No baseline cleanup, staging, reset, stash or commit.

| Command / check | Result |
| --- | --- |
| `git diff --check -- docs/task-contracts/authorization.md` | Exit 0; no diagnostics. Untracked content additionally checked below. |
| `git diff --no-index --check /dev/null docs/task-contracts/authorization.md` | Exit 1, no diagnostics; exit denotes new-file difference, no whitespace errors. |
| `git diff --no-index --check /dev/null docs/task-results/AUTH-01.md` | Exit 1, no diagnostics; exit denotes new-file difference, no whitespace errors. |
| `git status --short` | Exit 0; existing dirty tree plus the two new document directories; exact file scope confirmed below. |
| `python3 /tmp/auth01-validate-docs.py` — links | Exit 0; `Markdown links: 29 checked; 0 errors`. Existing files and heading/explicit-anchor fragments checked. |
| Same script — dependency/scope/baseline | `Baseline: 167 files; 0 modified; 0 unexpected new paths`; `Dependency/allow-list: AUTH-01 None; two declared planned paths verified`. |
| App builds / analysis / harness / emulators | Not run: AUTH-01 is documentation only; explicit card requires diff/link/dependency checks. No application code changed. |

Independent contract review resolved one P2 finding: company role grants now
allow separate Owner/Operations/Rider roles with explicit selection and no union.
Reviewer also clarified nonterminal empty pagination and offline local financial
recording. Final review approved both corrected documents with no unresolved
findings and independently reran the validator/whitespace checks with the results
recorded above. This approves AUTH-01 documentation acceptance only.

Discovery used Graft skeleton/grep first for source needs, then bounded source
reads for decisive behavior. One initial `graft grep 'AUTH-01' SARI_SUPPLY_TASKS.md`
used the file as a repository argument and failed `ENOTDIR`; no result or saving
claimed. Two absent source-prefix lookups and one too-specific provider lookup
returned no matches; corrected to indexed source locations. One nonexistent
`management-service.ts` read failed; inspected actual operational reader instead.
Embedding the validator initially caused its Markdown regex to match its own
fenced code; the validator now excludes fenced blocks before link/anchor scans.
No failures above are represented as verification passes.

Graft per-call savings are tool estimates, not measured model/account billing
savings. Author-only total: approximately **56,596 tokens** across 21 calls that emitted
a savings line.
Parent's prior broad discovery call is excluded from this author-only total.

## Manual evidence, limitations and next action

Performed source/document trace of every canonical actor through sign-in,
permitted action, denial and reconnect in the contract matrix/trace table. This
is documentation evidence, not a live login, permission or offline test. Existing
membership emulator assertions were read, not executed. No visible screen added;
required loading/empty/denied/pending/offline/validation/failure/retry/success and
context-switch states are specified for downstream acceptance.

Pending gates: coordinator integration/version reservation,
company/provider/schema/index implementation, actual Development company/staff/
rider identities, current App Check/backend sign-in, invitation races/removal,
legacy mixed-root/old-client replay rehearsal, live offline clock/device/role
switching and authorization integration. Existing CURRENT_STATE describes some
Development backend/phone evidence, but that is not company-contract acceptance.
No live identity, approved secret configuration, backend, hardware or Production
schema was inspected or exercised by AUTH-01. No printer/camera/GPS gate applies
to this document-only change; relevant later workflows retain their hardware gates.

Risks: unsafe legacy permissions remain in current runtime until separately
implemented closures; unresolved ownership blocks future writes rather than
promoting users or deleting evidence; current historical-assignment recovery is
not implemented. New schema/API names remain provisional until coordinator
reservation. No migration or production-readiness claim.

Next action: coordinator integrates the independently reviewed contract and
handoff, reserves versions/shared wiring, and updates AUTH-01's checklist row
before any dependent worker starts. Author has completed scoped documentation
work and final checks; no later task, deployment or migration executed.

## Reproducible scoped validator

The command above uses this exact transient script. Baseline SHA-256 values were
captured before edits in `/tmp/auth01-baseline-hashes.json`; it maps each of the
167 preexisting modified/untracked file paths to its content digest, or null for
a missing file. The retained baseline belongs to this session, not repository
business data. Reproduce baseline capture before edits in a new session; never
replace it after edits to manufacture a preservation pass. `/tmp` snapshots and
validator are transient verification artifacts; only the two declared documents
are repository writes.

```python
from pathlib import Path
import re
import json
import hashlib
import subprocess
import urllib.parse

files = [Path('docs/task-contracts/authorization.md'), Path('docs/task-results/AUTH-01.md')]

def without_fenced_code(source):
    return re.sub(r'(?ms)^([`~]{3,})[^\n]*\n.*?^\1[ \t]*$', '', source)

def anchors(path):
    source = without_fenced_code(path.read_text())
    found = set(re.findall(r'<a\s+(?:name|id)=["\x27]([^"\x27]+)', source))
    counts = {}
    for line in source.splitlines():
        match = re.match(r'^#{1,6}\s+(.+?)\s*#*$', line)
        if not match:
            continue
        key = match.group(1).strip().lower().replace('`', '')
        key = re.sub(r'[^\w\- ]', '', key).replace(' ', '-')
        duplicate = counts.get(key, 0)
        counts[key] = duplicate + 1
        found.add(key if duplicate == 0 else key + '-' + str(duplicate))
    return found

errors = []
checked = 0
for path in files:
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', without_fenced_code(path.read_text())):
        if re.match(r'^[a-z]+://', target):
            continue
        target = target.split(' "')[0].strip('<>')
        locator, _, fragment = target.partition('#')
        destination = (path.parent / urllib.parse.unquote(locator)).resolve() if locator else path.resolve()
        checked += 1
        if not destination.is_file():
            errors.append(f'{path}: missing {target}')
        elif fragment and urllib.parse.unquote(fragment) not in anchors(destination):
            errors.append(f'{path}: missing fragment {target}')
print(f'Markdown links: {checked} checked; {len(errors)} errors')
for error in errors:
    print(error)
baseline = json.loads(Path('/tmp/auth01-baseline-hashes.json').read_text())
changed = [path for path, digest in baseline.items() if
           (hashlib.sha256(Path(path).read_bytes()).hexdigest() if Path(path).is_file() else None) != digest]
current = set(filter(None, subprocess.check_output(
    ['git', 'ls-files', '--modified', '--others', '--exclude-standard', '-z']).decode().split('\0')))
unexpected = current - set(baseline) - set(str(path) for path in files)
print(f'Baseline: {len(baseline)} files; {len(changed)} modified; {len(unexpected)} unexpected new paths')
for path in changed:
    print('CHANGED', path)
for path in sorted(unexpected):
    print('UNEXPECTED', path)
guide = Path('SARI_SUPPLY_TASKS.md').read_text()
card = guide.split('### AUTH-01 —', 1)[1].split('<a id="auth-02"', 1)[0]
assert '**Dependencies:** None' in card and 'Dependencies: None.' in card
assert all(str(path) in card for path in files)
print('Dependency/allow-list: AUTH-01 None; two declared planned paths verified')
if errors or changed or unexpected:
    raise SystemExit(1)
```
