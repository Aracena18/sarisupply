# SariSupply Disaster Recovery Runbook

**Emergency Incident Response, Data Restoration, and Crisis Management Guide**  
*Document Version: 1.0 (Phase 9 Production Release)*

---

## 1. Incident Classification Matrix

| Incident Tier | Severity | Trigger / Symptoms | Immediate Mitigation |
| :--- | :--- | :--- | :--- |
| **Tier 1: Outbox Congestion** | Moderate | Outbox queue > 100 operations; yellow sync badge; intermittent Wi-Fi | Connect to backup cellular hotspot; tap manual sync in Catalog screen. |
| **Tier 2: Clock Drift / Token Expiry** | High | "Offline credentials expired (>7 days)" or "Monotonic clock drift"; PIN sign-in blocked | Connect POS to internet for 30s to re-synchronize time and refresh device security lease. |
| **Tier 3: Database Corruption** | Critical | SQLite `PRAGMA integrity_check` fails; disk I/O errors; app crashes on query | Execute Playbook 1: Restore from Encrypted Backup Archive. |
| **Tier 4: Device Loss / Theft** | Critical | Physical POS phone stolen, lost, or broken beyond repair | Execute Playbook 2: Scoped Hardware Revocation & Re-enrollment. |
| **Tier 5: Concurrent Shortage Conflict** | Low | Two offline devices sold the same physical item; negative cloud stock | Execute Playbook 4: Reconcile Stock via Physical Count & Audit Trail. |

---

## 2. Playbook 1: Restoring Corrupted Database from Encrypted Backup

When SQLite database corruption occurs (e.g., sudden phone battery shutdown during flash write):

### Step 1: Diagnose Database Integrity
1. Open POS application.
2. Navigate to **Operations -> Diagnostics & Recovery**.
3. Inspect the **Local SQLite Database Health** card:
   - If `SQLite Integrity Check` reads anything other than `ok`, the database B-tree structure is compromised.
   - If `quickCheckPassed` is `false`, immediate restoration is mandatory.

### Step 2: Retrieve Encrypted Backup
1. Retrieve the latest daily encrypted backup JSON from:
   - Store Manager's external USB flash drive or SD card backup.
   - Store backup copy in cloud drive or email attachment.

### Step 3: Inspect & Pre-Verify Archive
1. In the **Disaster Recovery & Encrypted Restore** card on the Diagnostics screen:
   - Paste the backup JSON into the text field (or tap **Paste from Clipboard**).
   - Enter the encryption passphrase used when the archive was created.
2. Tap **Inspect & Verify Backup**.
   - The engine validates the PBKDF2 HMAC-SHA256 key derivation.
   - The engine decrypts ciphertext in-memory using AES-256-GCM.
   - The engine verifies that the computed SHA-256 digest exactly matches the plaintext integrity manifest.
   - If someone tampered with the file or the password is wrong, the tool rejects it with `VERIFICATION FAILED`.

### Step 4: Execute Atomic Database Restore
1. Once verified, tap **Execute Restore**.
2. A confirmation dialog shows the number of sales, shifts, ledger entries, and stock items to be restored.
3. Tap **Restore Data**.
4. The system opens an atomic SQLite transaction:
   - Restores all historical `checkout_events` and `checkout_sales`.
   - Restores all cashier shifts and float amounts.
   - Restores append-only `ledger` movements with `INSERT OR IGNORE` preserving existing entries.
   - Replaces `stock` table balances.
5. The system performs an immediate post-restore `PRAGMA integrity_check` confirming `isHealthy == true`.

---

## 3. Playbook 2: POS Device Loss, Theft, or Hardware Failure

If a POS phone is lost or stolen:

### Step 1: Immediate Remote Revocation
1. Log into the **Admin Web Dashboard** using an authorized Manager or Owner account.
2. Navigate to **Store Management -> Devices**.
3. Locate the compromised device ID and tap **Revoke Device**.
4. The server flags the device as revoked. Any subsequent attempt to sync or authenticate from that device is blocked immediately.

### Step 2: Provision Replacement POS Device
1. Take a fresh Android phone or tablet.
2. Install the **SariSupply POS APK** (`app-prod-release.apk`).
3. Open the app and tap **Activate Device**.
4. In Admin Web or Owner POS, click **Generate Activation QR** for the branch.
5. Scan the QR code with the replacement phone camera. The hardware token is minted and bound to the branch.

### Step 3: Fast State Synchronization
1. The new device automatically initiates a bounded Delta Sync against Cloud Firestore.
2. Pulls active product catalog, barcode mappings, multi-unit prices, customer credit balances, and active supplier catalog.
3. Cashiers sign in using their established PINs.

---

## 4. Playbook 3: Extended Internet Outage (> 7 Days)

SariSupply enforces a strict 7-day monotonic offline credential policy to prevent compromised hardware from running indefinitely undetected:

### Symptoms
- Cashier enters valid PIN, but receives: `"Offline authorization window expired. Please connect to internet."`
- Wall clock manipulation was detected (device clock rolled backward).

### Recovery Procedure
1. Turn on a mobile phone personal hotspot.
2. Connect the POS phone to the hotspot Wi-Fi.
3. Open the POS app. The app automatically detects internet connectivity:
   - Transmits queued outbox transactions.
   - Validates device token against backend HTTPS auth endpoint.
   - Refreshes the 7-day monotonic lease window.
4. Turn off hotspot. The POS register resumes normal 100% offline operation.

---

## 5. Playbook 4: Reconciling Concurrent Negative Stock Discrepancies

If two cashiers on separate offline POS devices sell the last unit of an item simultaneously:

### Operational Behavior
1. In accordance with the approved Free Production Platform specification, **offline physical sales are never blocked by zero stock**, ensuring paying customers at the counter are never turned away.
2. Both sales commit locally with negative stock deltas.
3. Upon reconnecting, both sales sync to Cloud Firestore. The cloud stock ledger records a negative balance (e.g., `-1`).

### Reconciliation Procedure
1. In the POS app, the **Notification Bell** displays a warning: `"Negative Inventory Detected for [Product SKU]"`.
2. A store clerk conducts a physical shelf count.
3. Navigate to **Operations -> Adjustments**.
4. Select the affected product, enter the actual physical quantity counted on the shelf, and select the adjustment reason (e.g., `"Unrecorded delivery found"` or `"Negative balance reconciliation"`).
5. The adjustment produces a compensating immutable ledger entry that balances the ledger to the physical reality.
