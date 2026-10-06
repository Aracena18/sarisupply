# Explicit client builds

Use `bash tool/build_client.sh` after the development HTTPS service is deployed.
The script validates public settings before invoking Flutter. It builds artifacts;
it does not install on phones, deploy services, or publish applications.

Create a local JSON file with the deployed origin:

```json
{
  "SARISUPPLY_ENV": "dev",
  "SARISUPPLY_API_URL": "https://REPLACE-WITH-DEPLOYED-ORIGIN"
}
```

Replace the origin before building. Do not use a placeholder as an operational
endpoint. `GOOGLE_SERVER_CLIENT_ID` is optional; known Firebase projects use their
registered Android server client ID. These settings are public and included in the
client artifact. Web builds also require the public
`SARISUPPLY_APP_CHECK_WEB_KEY` registered for the matching Firebase project and
allowed web origin. Add it to the Admin settings JSON before running the web build.
For new Fraud Defense (reCAPTCHA Enterprise) registrations, also set
`SARISUPPLY_APP_CHECK_WEB_PROVIDER` to `enterprise`. Existing reCAPTCHA v3
registrations retain the `recaptcha-v3` default. The provider must match the key
registered in Firebase App Check; Enterprise uses a score-based Web key, not a
classic secret key. Server token verification remains required for both providers.
Never include service-account credentials, tokens, or signing
passwords.

```bash
bash tool/build_client.sh pos dev apk-debug /absolute/path/client.dev.json
bash tool/build_client.sh admin dev web /absolute/path/client.dev.json
bash tool/build_client.sh driver dev apk-debug /absolute/path/client.dev.json
```

For production, the JSON environment must be `prod`. Android production release
builds fail when signing credentials are absent. Supply these environment variables
through the release environment or secret store:

- `SARISUPPLY_KEYSTORE_PATH`: existing keystore path.
- `SARISUPPLY_KEY_ALIAS`: release key alias.
- `SARISUPPLY_KEYSTORE_PASSWORD`: keystore password.
- `SARISUPPLY_KEY_PASSWORD`: key password.

Register the release certificate fingerprint with the matching Firebase Android
app and verify Google sign-in and App Check on a real device. Debug builds use
debug signing. Development release builds also use debug signing and are not
production distribution artifacts.

Compile-only checks without settings can still use the commands in
`tool/verify_local.sh`. Their setup-incomplete screen does not establish backend
connectivity or operational readiness. Live acceptance must use the deployed URL,
current memberships, assigned devices/cashiers, and server-backed business records.

Development Admin web uses Firebase Hosting, while the API remains on Deno Deploy.
Current Firebase CLI rejects `../apps/admin/build/web` outside the Firebase project
directory. Deploy from an isolated staging directory containing the compiled web
artifact under `web/` and a `firebase.json` with only the repository hosting section,
changing its `public` value to `web`. Run the CLI with Node 22, the private
Development service-account file through `GOOGLE_APPLICATION_CREDENTIALS`,
`--only hosting`, and explicit `--project sarisupply-dev-aracena18`. Never copy
credentials into the staging directory. Fixed-name Flutter assets must revalidate
rather than use immutable year-long caching, so updates load the current build.
