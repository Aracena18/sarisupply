# SariSupply Operator Runbook

**Production Operating Procedures for Store Owners, Managers, Cashiers, and Drivers**  
*Document Version: 1.0 (Phase 9 Production Release)*

---

## 1. System Architecture & Constraints

SariSupply is an offline-first retail operating system and supply distribution platform built exclusively with Flutter clients, SQLite local durability, and a zero-cost Firebase Spark cloud backend.

### Core Architectural Invariants
1. **Zero Cloud Hosting Fees**: Operates strictly within the free Firebase Spark plan (zero paid Cloud Functions, zero paid cloud storage, zero third-party payment gateway cuts).
2. **Offline-First Durability**: Point-of-Sale (POS) and Driver apps operate 100% offline using local SQLite transactions. Sales, cash shifts, and inventory movements commit locally before syncing.
3. **Monotonic Security & 7-Day Offline Limit**: Cashier PINs and device credentials operate up to 7 consecutive days offline using monotonic clock validation. Device reboots or 7 days elapsed require an online handshake.
4. **Immutable Financial Ledger**: All sales, returns, refunds, voids, and debt repayments produce append-only ledger entries. Data is never deleted or altered in place.

---

## 2. Deployment & Installation

### 2.1 Admin Web App Deployment (Firebase Hosting)
The Admin operations dashboard runs as a Flutter Single Page Application (SPA) hosted on Firebase Hosting:

1. **Build Flutter Web Artifact**:
   ```bash
   cd apps/admin
   flutter build web --release
   ```
2. **Deploy to Firebase Hosting**:
   ```bash
   cd ../../firebase
   firebase deploy --only hosting
   ```
3. **Access Admin Portal**: Navigate to `https://sarisupply-prod-aracena18.web.app` (or your configured custom domain). Sign in with an authorized Google account.

### 2.2 Android POS and Driver APK Installation
1. **Build Release APKs**:
   ```bash
   # Build POS APK
   cd apps/pos
   flutter build apk --flavor prod --release

   # Build Driver APK
   cd apps/driver
   flutter build apk --flavor prod --release
   ```
2. **Sideload APKs**: Transfer the generated APKs (`build/app/outputs/flutter-apk/app-prod-release.apk`) to target Android phones/tablets via USB or secure internal link.
3. **Grant Required Permissions**: Camera (for barcode scanning) and Location (for device delivery routing intents).

---

## 3. Store Provisioning & Identity Setup

### 3.1 Merchant Application & Owner Approval
1. New store owners submit a merchant application via the POS device on initial launch.
2. Platform Administrators review the business name, address, tax details, and contact info in the Admin Web dashboard (`Merchant Review`).
3. Upon approval, the merchant tenancy is activated with default branch and catalog fixtures.

### 3.2 Branch and POS Device Enrollment
1. Store Owners can create branches from the POS `Operations -> Store Management` menu or Admin Web.
2. In the branch settings, click **Activate New POS Device**.
3. Scan the device activation QR code on the target phone POS to bind the hardware identity.

### 3.3 Cashier PIN Setup & Roster Management
1. Cashier accounts are created with a 4-to-6 digit numeric PIN.
2. Temporary PINs force the cashier to enter a permanent personal PIN on their first sign-in.
3. Cashiers switch shifts on POS by tapping the cashier avatar and entering their PIN. PIN verification runs locally against Argon2id/scrypt derived verifiers stored securely on the device.

---

## 4. Daily Point-of-Sale Procedures

### 4.1 Opening the Register (Shift Float)
1. At the start of each business day, the cashier signs in and taps **Start Shift**.
2. Count the physical cash in the drawer and enter the **Opening Float** (e.g., ₱1,000.00).
3. The float is recorded atomically in the local SQLite cash drawer journal.

### 4.2 Checkout Sales Workflow
1. **Add Items**: Scan barcodes using the rear phone camera, or search the catalog by name or SKU.
2. **Select Unit**: For multi-unit items (e.g., piece, pack, box), select the unit from the dropdown. The price and unit factor adjust automatically.
3. **Tender Types**:
   - **Cash**: Enter the tendered amount. The app computes change in centavos.
   - **Manual QR (GCash / Maya)**: Instruct customer to scan store QR standee. Cashier verifies the transfer in the store's phone wallet and enters the reference number.
   - **Utang / Store Credit**: Select an authorized customer. The app validates customer credit limits and records the transaction in the debt ledger.
4. **Receipt Presentation**: Tap **Print / Preview Receipt** to stream ESC/POS commands to a Bluetooth/USB thermal printer or share the ASCII receipt summary.

### 4.3 End-of-Day Z-Reading Closure
1. At the end of the shift, tap **Operations -> Reports & Z-Reading**.
2. Select **Z-Reading Preview** to review gross sales, net sales, VAT 12%, tender breakdowns, and cash drawer balance.
3. Count the physical cash drawer and enter the **Counted Cash**. Any discrepancy (overage or shortage) is logged with an explanation.
4. Tap **Close Shift & Print Z-Reading**. This commits the final closing record and locks the shift.

---

## 5. Thermal Receipt Printing

SariSupply contains a 100% pure Dart ESC/POS print builder requiring zero paid cloud print subscriptions:
1. **Paper Sizes**: Supports standard 58mm (32 characters/line) and 80mm (48 characters/line) thermal rolls.
2. **Hardware Connection**: Connects to thermal receipt printers via Bluetooth SPP, USB OTG, or raw TCP sockets (port 9100).
3. **Cash Drawer Kick**: Automatically sends pulse `ESC p 0 25 250` upon cash sale settlement to pop the register drawer.

---

## 6. Inventory, Procurement & Restocking

### 6.1 Shortage Detection & Restock Proposals
1. Shortage alerts trigger automatically when physical stock reaches 10 units or less.
2. Open **Operations -> Restock Orders**. Tap **Add All Shortages** to generate replenishment lines.
3. Submit the proposal to the Store Owner for review.
4. The Owner reviews, adjusts quantities, and taps **Approve Proposal**.

### 6.2 Warehouse Fulfillment & Supplier POs
1. Warehouse staff open **Operations -> Warehouse Ops**.
2. View approved restock proposals in the Pick & Pack queue.
3. Check off items as they are picked, pack them into a container, and apply a tamper-evident seal code.
4. When supplier purchase orders arrive, tap **PO Receiving** to log received stock, batch numbers, and expiry dates.

---

## 7. Delivery Run & Driver Routing

1. Driver opens the **SariSupply Driver App**.
2. The active delivery run displays sequential stops with destination addresses and contact info.
3. Tap **Navigate** to open the destination in Google Maps / Waze via external platform URL intent (zero paid embedded Maps API costs).
4. Upon arrival, tap **Deliver Stop**:
   - Verify package container and tamper seal.
   - Adjust quantities if items are damaged or returned, selecting return reasons.
   - Collect Cash on Delivery (COD) if applicable.
   - Have store recipient sign directly on the touch screen canvas.
5. Tap **Submit Delivery Proof**. The signature is serialized to SVG vector path data and queued for offline sync.

---

## 8. Backup Archival & Data Retention

1. **Daily Backup Export**:
   - Go to **Operations -> Data Backup & Archival**.
   - Enter a secure passphrase (min 6 chars) and tap **Export Encrypted Backup Now**.
   - Copy or save the encrypted JSON payload to a secure external USB drive or cloud drive.
2. **90-Day Retention Policy**:
   - Detailed local transaction records older than 90 days are automatically archived upon cloud sync confirmation to preserve phone flash memory and SQLite performance.
   - Encrypted backup archives preserve full multi-year history for tax auditing.
