# Firebase environments

SariSupply uses separate Firebase projects. Run Firebase CLI commands from
`firebase/` and select `--project dev` or `--project prod` explicitly. The
aliases are in `firebase/.firebaserc`; there is no default project.

| Environment | Project ID | Firestore location |
| --- | --- | --- |
| Development | `sarisupply-dev-aracena18` | `asia-southeast1` |
| Production | `sarisupply-prod-aracena18` | `asia-southeast1` |

Each project has POS Android, Driver Android, and Admin Web registrations.
Development Android package names end in `.dev`; Production package names do
not. FlutterFire config files live at `apps/*/lib/firebase_config_dev.dart`
and `apps/*/lib/firebase_config_prod.dart`. Android Google Services files live
under each app's `android/app/src/dev/` and `android/app/src/prod/` directories.

Google Sign-In is enabled in both projects. The Development POS and Driver
Android registrations have the current local debug keystore's SHA-1 and
SHA-256 fingerprints. When the development signing certificate changes,
register the new hashes and regenerate the corresponding `google-services.json`
files. Before a Production release, configure a dedicated release signing key,
register its SHA-1 and SHA-256 hashes in both Production Android app
registrations, and regenerate the Production Google Services files. The current
Gradle release configuration still uses debug signing and is not suitable for
distribution.

App startup requires `--dart-define=SARISUPPLY_ENV=dev` or `prod`. Native
Google Sign-In additionally requires `GOOGLE_SERVER_CLIENT_ID` when a user
starts sign-in. The Development web OAuth client ID is
`594903185972-1dlngb8a6i0j6i87ss6nbaab2u1krdqg.apps.googleusercontent.com`;
the Production ID is
`110781011916-88507t6k0glkskp51460qa6bcm6oti8b.apps.googleusercontent.com`.
The Development Auth project authorizes `localhost` for local Admin web testing.
The Production project does not authorize `localhost`.

The Firestore databases are Standard edition, have delete protection enabled,
and use the repository's tested security rules. Rules allow only narrow reads
for a user's own profile, active membership, authorized branches, own merchant
applications, and active Admin record. Clients cannot write authorization,
credential, or audit documents. Run `npm run test:rules` in `firebase/functions`
through the Firestore emulator before changing rules.

The trusted Admin grant script requires an existing Firebase Auth user and
Google Application Default Credentials with access to the target project. From
`firebase/functions`, run `npm run build`, then
`npm run grant-admin -- --project sarisupply-dev-aracena18 --email <email>`
(or `--uid <uid>`). Repeat explicitly for Production when appropriate. It
writes an active `platformAdmins/{uid}` record and sets the small
`sarisupplyAdmin` custom claim. It is never exposed as a client callable.

Both projects currently have no billing account. Firebase Storage default
buckets require Blaze, and Cloud Functions deployment also requires Blaze.
After linking billing and setting budget alerts, provision each Storage bucket
in `asia-southeast1`, then deploy the tested Storage rules and Functions to
each project. Creating a bucket or deploying Functions before the security
rules and server flows are ready is not part of the current bootstrap.
