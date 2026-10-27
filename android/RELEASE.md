# Releasing LYO on Google Play — step by step

This guide is written for someone who does not code. Follow the steps in
order. You only do Part 1 and Part 2 **once**; Part 3 you repeat for every
new version.

Words you will see:

- **Upload key / keystore** — a small file (ending in `.jks`) plus two
  passwords. It proves to Google that a new version really comes from you.
  Think of it as the master key to your app's Play Store listing.
- **AAB (Android App Bundle)** — the file you upload to the Play Console.
  It ends in `.aab`.
- **versionCode** — a whole number that must go up by at least 1 with every
  upload (1, 2, 3 …). Users never see it.
- **versionName** — the version people see, like `1.0.1`.

---

## Part 1 — Create the upload key (once)

You need **Android Studio** (free, from developer.android.com/studio).
Install it and open it once so it finishes setting itself up.

1. Make a folder **outside** the LYO code folder to keep your keys, for
   example `Documents/lyo-keys`. Never put the key inside the code folder.
2. In Android Studio choose **File → Open** and open the `android` folder
   of the LYO project. Wait until the bar at the bottom stops loading.
3. Choose **Build → Generate Signed App Bundle or APK…**, pick
   **Android App Bundle**, then **Next**.
4. Under *Key store path* click **Create new…** and fill in:
   - **Key store path:** your keys folder, file name `lyo-upload.jks`
   - **Password / Confirm:** a long, strong password (this is the *store password*)
   - **Alias:** `lyo-upload`
   - **Key password:** another strong password (this is the *key password*)
   - **Validity (years):** `30`
   - **First and Last Name:** your name; **Organization:** LYO; **Country Code:** e.g. `US`
5. Click **OK**, then **Cancel** to close the wizard (you will build later).

> Prefer the terminal? This command does the same thing (it asks for the
> passwords and details):
> `keytool -genkeypair -v -keystore ~/Documents/lyo-keys/lyo-upload.jks -keyalg RSA -keysize 2048 -validity 10950 -alias lyo-upload`

### Back up the key right now

If you lose the key or its passwords you cannot publish updates until
Google resets it (that takes days and a support request).

- Save **both passwords** and the alias `lyo-upload` in a password manager
  (1Password, Bitwarden, iCloud Keychain…).
- Copy `lyo-upload.jks` to **two** safe places, e.g. an encrypted USB drive
  and your password manager's file attachment. Not to a public or shared
  folder, and **never** into GitHub.

## Part 2 — Tell the build where the key is (once per computer)

1. In the `android` folder of the project, create a plain-text file named
   exactly `keystore.properties` (TextEdit: *Format → Make Plain Text*).
2. Put these four lines in it, using your own path and passwords:

   ```
   storeFile=/Users/YOUR-NAME/Documents/lyo-keys/lyo-upload.jks
   storePassword=YOUR-STORE-PASSWORD
   keyAlias=lyo-upload
   keyPassword=YOUR-KEY-PASSWORD
   ```

3. Save. This file is already listed in `.gitignore`, so git will not upload
   it. (Check: `git status` must **not** show `keystore.properties`.)

> For automated builds (a CI server) you can skip the file and set these
> environment variables instead: `LYO_UPLOAD_STORE_FILE`,
> `LYO_UPLOAD_STORE_PASSWORD`, `LYO_UPLOAD_KEY_ALIAS`,
> `LYO_UPLOAD_KEY_PASSWORD`.

If either is missing, debug builds still work, and a release build stops
with a message pointing back to this page.

### Add the Firebase file (`google-services.json`)

Push notifications and *Continue with Google* need this file. It is not
kept in git; each computer that builds the release needs a copy.

1. Go to **console.firebase.google.com** and open the project **lyo-app**.
2. Click the gear ⚙ → **Project settings** → **Your apps**.
3. If there is no Android app with package name **`com.lyo.app`**, click
   **Add app → Android**, enter `com.lyo.app`, and finish the steps.
4. In that Android app, under **SHA certificate fingerprints**, add the
   SHA-1 fingerprints so *Continue with Google* works:
   - your **upload key** — in a terminal run
     `keytool -list -v -keystore ~/Documents/lyo-keys/lyo-upload.jks -alias lyo-upload`
     and copy the `SHA1:` line;
   - Google's **app signing key** — after your first upload, in the Play
     Console open **Test and release → App integrity → App signing** and copy
     its SHA-1. (Users who install from Play get the app signed with *this*
     key, so Google sign-in fails for them until it is added.)
5. Click **Download google-services.json** and put the file at
   `android/app/google-services.json`.

## Part 3 — Build the release bundle (every new version)

1. Decide the new numbers. Look at the Play Console for the last
   versionCode you uploaded and add 1. Choose the visible version, e.g. `1.0.1`.
2. In Android Studio, open the **Terminal** tab at the bottom and run (from
   the `android` folder), replacing the numbers:

   ```
   gradle :app:bundleRelease -PLYO_VERSION_CODE=2 -PLYO_VERSION_NAME=1.0.1
   ```

   *(If `gradle` is not found, use the Gradle panel on the right instead:
   **app → Tasks → bundle → bundleRelease**. In that case put the two
   numbers in `android/gradle.properties` as `LYO_VERSION_CODE=2` and
   `LYO_VERSION_NAME=1.0.1` first.)*
3. When it says **BUILD SUCCESSFUL**, your file is at
   `android/app/build/outputs/bundle/release/app-release.aab`.
4. In the **Play Console**, open LYO → **Test and release** → choose a track
   (start with **Internal testing**) → **Create new release** → upload the
   `.aab` → add release notes → **Save** → **Review release** → **Start rollout**.

The release build always talks to the production server
(`https://api.lyoai.app`). To build a tester copy that talks to the staging
server instead, see `docs/STAGING.md`.

## Before the first public release — checklist

- [ ] Upload key created and backed up in two places (Part 1).
- [ ] `keystore.properties` and `google-services.json` in place (Part 2), and
      neither shows up in `git status`.
- [ ] Play Console: **Play App Signing** turned on (the default for new apps).
- [ ] Play Console **App content** filled in: privacy policy URL
      `https://lyoai.app/privacy`, **Data safety** form (must match the
      privacy policy), content rating, target audience, and the account
      deletion URL `https://lyoai.app/support` (Delete account is in
      Settings in the app).
- [ ] Tested the build from **Internal testing** on a real phone: sign up,
      log in, Continue with Google, notifications, Delete account.
