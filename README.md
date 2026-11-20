# Workout Log — offline iPhone workout logger

SwiftUI + SwiftData, iOS 17+, no third-party libraries, no accounts, no internet.
Every user's data stays on their own phone.

---

## 1. Project structure

```
WorkoutLog/
├── WorkoutLog.xcodeproj            ← double-click to open in Xcode
└── WorkoutLog/                     ← every file in here is compiled automatically
    ├── App/
    │   ├── WorkoutLogApp.swift     entry point, database, sample data, environment
    │   ├── AppState.swift          "is the live workout on screen?"
    │   └── RootView.swift          tab bar + live-workout layer + restore on launch
    ├── Models/                     SwiftData @Model classes
    │   ├── Routine.swift           Routine (folder) + RoutineExercise (ordered link)
    │   ├── Exercise.swift          shared exercise library (targets, photo, note)
    │   ├── WorkoutSession.swift    WorkoutSession → WorkoutExercise → WorkoutSet
    │   └── BackupModels.swift      Codable JSON format for export/import
    ├── Services/                   business logic, no UI
    │   ├── WorkoutService.swift    start / prefill / add-remove sets / finish / delete
    │   ├── RoutineService.swift    create / rename / duplicate / reorder / delete
    │   ├── ProgressionService.swift last time, overload rule, PRs, chart data
    │   ├── RestTimerService.swift  end-date based timer, survives background/kill
    │   ├── NotificationService.swift local "rest is over" notification
    │   ├── BackupService.swift     JSON export + merging import
    │   ├── SampleDataService.swift Push / Pull / Legs on first launch
    │   └── ImageService.swift      photo → small JPEG thumbnail
    ├── ViewModels/
    │   ├── ActiveWorkoutViewModel.swift
    │   ├── ExerciseEditorViewModel.swift
    │   └── SettingsViewModel.swift
    ├── Views/
    │   ├── Routines/   RoutinesListView, RoutineDetailView, ExercisePickerView,
    │   │               ExerciseEditorView, ExerciseLibraryView
    │   ├── Workout/    ActiveWorkoutView, WorkoutExerciseHeader, OverloadBanner,
    │   │               SetRowView, RestTimerView
    │   ├── History/    HistoryListView, WorkoutDetailView, ExerciseProgressView (chart)
    │   ├── Settings/   SettingsView
    │   └── Components/ NumberInputField, ExerciseThumbnail, ResumeWorkoutBar,
    │                   CameraPicker, ActivityView (share sheet)
    ├── Utilities/      WeightUnit (+ RestTime), AppSettings, Formatters, Haptics, KeyboardHelpers
    └── Assets.xcassets AppIcon (1024 px, included) + AccentColor (orange, light/dark)
```

### Key design decisions
- **Weights are stored in kg** and converted for display, so switching kg ⇄ lbs never corrupts history.
- **Exercises live in a shared library.** Routines point to them, so one exercise in three routines has one history, one PR, one chart. Editing an exercise updates it everywhere.
- **The live workout is a normal database record** (`isFinished == false`) saved on every tap. If the app is closed, killed or crashes, it is reopened on next launch.
- **The rest timer stores an end time, not a countdown.** Remaining time is always `end − now`, so it's correct after locking the phone. A local notification is scheduled for the same moment so you get a sound when the app isn't open.
- **Progressive overload rule** (`ProgressionService.overloadStatus`): last session's completed sets all at the same weight **and** all ≥ max reps → banner "You hit 12 reps on every set last time — add 2.5 kg!" with suggested weight = last + 2.5 kg (or + 5 lbs). Otherwise a subtle "Keep this weight" hint.

---

## 2A. No Mac? Build it in the cloud (Windows-friendly)

Everything below happens in a web browser on Windows. Codemagic runs Xcode on its own Macs; the project already contains `codemagic.yaml` with two workflows.

**Accounts you'll create:** GitHub (free), Codemagic (free plan includes macOS build minutes each month), and — for installing on your phone — the paid Apple Developer Program.

### Step 1 – Put the code on GitHub (free)
1. Sign up at **github.com** → **+ → New repository** → name `WorkoutLog` → **Private** → *Create*.
2. On the empty repo page click **uploading an existing file**.
3. Unzip `WorkoutLog.zip`, open the `WorkoutLog` folder, select **everything inside it** (`WorkoutLog`, `WorkoutLog.xcodeproj`, `codemagic.yaml`, `README.md`) and drag it onto the page. Wait for all files to appear → **Commit changes**.
   - Check that `codemagic.yaml` sits at the top level of the repo, not inside a sub-folder.

### Step 2 – Check that it compiles (free, no Apple account)
1. Sign up at **codemagic.io** with your GitHub account and add the `WorkoutLog` repository.
2. Open the app in Codemagic → **Start new build** → choose workflow **"1 · Check it compiles (free)"** → *Start*.
3. Green = the code compiles. Red = open the failed step, copy the red error lines and send them to Claude to fix; upload the fixed files to GitHub and build again.

### Step 3 – One-time Apple setup (paid Apple Developer Program)
1. Enroll at **developer.apple.com/programs** (works from Windows in a browser) and wait for approval.
2. **Register the app ID:** developer.apple.com → *Certificates, IDs & Profiles → Identifiers → +* → App IDs → App → Description `Workout Log`, **Bundle ID (Explicit)** e.g. `com.yourname.workoutlog` → Continue → Register.
3. **Create the app record:** appstoreconnect.apple.com → *Apps → + → New App* → iOS, a unique name, your bundle ID, SKU `workoutlog1`.
4. **Create an API key for Codemagic:** App Store Connect → *Users and Access → Integrations → App Store Connect API* → **+** → name `Codemagic`, access **App Manager** → Generate → **Download** the `.p8` file (only possible once!). Note the **Issuer ID** and **Key ID**.
5. **Give the key to Codemagic:** Codemagic → *Team settings → Team integrations → Developer Portal → Manage keys → Add key* → name it exactly **`Codemagic API key`**, paste Issuer ID + Key ID, upload the `.p8` → Save.
6. **Signing certificate:** Codemagic → *Team settings → codemagic.yaml settings → Code signing identities → iOS certificates* → **Generate certificate** (type Apple Distribution) → give it a name → save. (Download the backup it offers and keep it safe.)
7. **Provisioning profile:** developer.apple.com → *Profiles → +* → **App Store Connect** → pick your app ID → pick the certificate Codemagic just made → name `Workout Log App Store` → Generate. Then in Codemagic → *Code signing identities → iOS provisioning profiles* → **Fetch profiles** → select it → save.

### Step 4 – Build and install
1. In GitHub, open `codemagic.yaml` → ✏️ edit → replace **both** `com.CHANGE-ME.workoutlog` with your bundle ID → Commit.
2. Codemagic → **Start new build** → **"2 · TestFlight release"**. When it's green, the build is uploaded to App Store Connect.
3. App Store Connect → your app → **TestFlight** → wait until the build shows *Ready to Test* (Apple processing, often 5–30 min). Under **Internal Testing** create a group and add yourself.
4. On your iPhone install **TestFlight** from the App Store, sign in with the same Apple ID → **Install** Workout Log.
5. For friends, follow section 4 below from "Invite friends". In `codemagic.yaml` you can later set `submit_to_testflight: true` so new builds are sent to Beta App Review automatically.

### Free alternative (no paid account, more hassle)
Workflow 1 also produces `WorkoutLog-unsigned.ipa` (Codemagic → build → Artifacts). A Windows sideloading tool such as **Sideloadly** (needs iTunes for Windows and a USB cable) can sign it with your free Apple ID and install it. Limits: it expires every **7 days** and must be re-installed, max 3 such apps per phone, and each friend has to do the same on their own PC. Use only software from its official site.

---

## 2B. Run it on your iPhone from a Mac

**You need:** a Mac with **Xcode 16 or newer** (free on the Mac App Store), an iPhone on **iOS 17+**, a USB cable (or same Wi-Fi after the first time), and an Apple ID.

1. **Unzip** `WorkoutLog.zip` and double-click **`WorkoutLog.xcodeproj`**.
2. **Sign the app** — in Xcode's left sidebar click the blue **WorkoutLog** project → target **WorkoutLog** → **Signing & Capabilities**:
   - Check **Automatically manage signing**.
   - **Team:** choose your Apple ID (if it's not listed: *Xcode → Settings → Accounts → +* and sign in).
   - **Bundle Identifier:** change `com.example.WorkoutLog` to something unique, e.g. `com.yourname.WorkoutLog`.
3. **Connect your iPhone** with the cable, unlock it and tap **Trust This Computer**.
4. **Turn on Developer Mode** on the iPhone (one time): *Settings → Privacy & Security → Developer Mode → On*, then restart the phone. (The option appears after the phone has been connected to Xcode once.)
5. At the top of Xcode, pick your iPhone in the device menu (next to the ▶︎ button) and press **▶︎ Run** (⌘R).
6. First time with a free Apple ID: the phone will say the developer isn't trusted. Go to *Settings → General → VPN & Device Management*, tap your Apple ID → **Trust**. Run again.
7. The app launches with three sample routines (Push / Pull / Legs).

> **Free Apple ID vs paid account:** with a free Apple ID the app works on your own phone but must be re-run from Xcode every **7 days**. With a paid Apple Developer Program membership it lasts a year and you can use TestFlight (section 4).

**Simulator:** you can also choose any iPhone simulator and press ▶︎. Everything works except taking photos with the camera (the "Take Photo" button is hidden there; "Choose Photo" works).

### If the project file won't open (fallback)
1. Xcode → *File → New → Project → iOS → App*. Product Name `WorkoutLog`, Interface **SwiftUI**, Storage **None**.
2. Delete the generated `ContentView.swift` and `WorkoutLogApp.swift`.
3. Drag the contents of the `WorkoutLog/` folder from this zip (App, Models, Services, …, Assets.xcassets) into the project's `WorkoutLog` group, replacing the existing Assets. Tick **Copy items if needed**.
4. Target → *General* → **Minimum Deployments: iOS 17.0**.
5. Target → *Info* → add **Privacy – Camera Usage Description** = "Take a photo of an exercise".
6. Target → *Build Settings* → **Swift Language Version: Swift 5**, and if present, **Default Actor Isolation: nonisolated**.

---

## 3. How to test each feature

Tip: run on a real phone for the timer, sound, vibration and camera.

**Routines (home screen)**
1. Tap **+** → name it → it opens straight away. Go back.
2. Swipe a routine **left** → *Rename* / *Delete* (delete asks to confirm). Swipe **right** → *Duplicate*. Long-press for the same menu.
3. Long-press and **drag** a routine to reorder (or tap **Edit** and use the ≡ handles). Kill and reopen the app — order is kept.

**Exercises inside a routine**
1. Open *Push* → **Add Exercise** → tick several (or *Create New Exercise*) → **Add**.
2. Tap an exercise to edit: name, **Choose Photo** / **Take Photo** (thumbnail appears next to the name), sets, min/max reps, rest (steps of exactly 15 s), weight step, note "seat height 4". Save.
3. Hold and drag to reorder; swipe left to remove from this routine (it stays in the library).
4. Add the same exercise to *Pull* too. Edit it in one routine → the change shows in the other (shared library). The *Exercises* screen (books icon) says "In 2 routines".

**Logging a workout**
1. Open *Push* → **Start Workout**. First time: allow notifications.
2. Each exercise shows "First time – no history yet". Tap a weight box → number pad opens with the value selected; type `60`. Use **− / +** to change by the exercise's weight step. Enter reps.
3. Tap the **circle** → turns into a green check, the row turns green, the phone gives a haptic tap and the **rest timer** appears.
4. **Add Set** / **Remove Set**, or swipe a set row left to delete it.
5. **Finish** → *Finish Workout*. Check **History**: date, duration, sets, volume.

**Prefill + "Last time"**
1. Start *Push* again. Every set is prefilled with what you did, and under the name you see e.g. **"Last time: 60 kg × 10, 10, 9"**.

**Progressive overload**
1. Bench Press in the samples has a rep range of 6–10. Log **3 sets of 60 kg × 10** and finish.
2. Start *Push* again → green banner **"You hit 10 reps on every set last time — add 2.5 kg!"**, *Suggested: 62.5 kg*. Tap **Apply** → all unfinished sets become 62.5. The banner disappears.
3. Repeat with 10, 10, 9 → no banner, only the hint "Keep this weight – aim for 10 reps on every set."
4. Settings → units **lbs** → the step becomes **+5 lbs**.
5. The routine screen shows a green ↑ next to exercises that are ready for more weight.

**Rest timer**
1. Complete a set → big countdown with **−15s / +15s / Skip**. Each press changes it by exactly 15 s.
2. Let it reach 0 with the app open → short chime + vibration. (The chime follows the ring/silent switch; vibration always works.)
3. Complete a set, **lock the phone** → at 0 you get a notification with sound. Same with the app in the background.
4. Change an exercise's rest time to 0:45 → its timer starts at 0:45.

**Never lose a workout**
1. Start a workout, log two sets, then **swipe the app away** in the app switcher.
2. Reopen → the workout comes back exactly as it was (timer too, if still running).
3. Tap the **⌄** button (top left) → *Minimize*: an orange "Workout in progress" bar appears at the top of every tab; tap it to return.

**History & progress**
1. **History** tab → workouts grouped by month → tap one for details.
2. **Edit** → change weights/reps, add/delete sets, remove an exercise, change the name or start/end time → **Done**.
3. *Delete Workout* (or swipe left in the list).
4. Tap an exercise in a workout (or History → chart icon → pick an exercise): **Personal record** card with 🏆, line chart of top weight over time (needs ≥ 1 session; looks best with 3+), list of past sessions with the PR marked.

**Settings, export & import**
1. Units kg/lbs, default rest (15 s steps), default weight step → create a new exercise and check the defaults.
2. **Export All Data** → share sheet → *Save to Files* (or AirDrop to your Mac).
3. Delete a routine, then **Import Data** → pick the file → "Routines added: 1 …". Nothing is ever duplicated or deleted by an import.
4. **Share Routines Only** → send to a friend → they tap **Import Data**. Their existing exercises with the same name are reused, so history stays together.
5. Moving to a new phone: export all on the old phone → AirDrop/iCloud Drive → install the app on the new phone → Import.

**Light / Dark mode** — Control Center → Dark Mode; every screen adapts.

---

## 4. Share the app with friends via TestFlight

TestFlight needs a **paid Apple Developer Program** membership (yearly fee — see developer.apple.com/programs). Each friend just needs an iPhone and the free **TestFlight** app.

**One-time setup**
1. Enroll at **developer.apple.com/programs** with your Apple ID and wait for approval.
2. In Xcode → Signing & Capabilities, choose the **paid team** and keep your unique bundle ID.
3. Go to **appstoreconnect.apple.com → Apps → + → New App**: platform iOS, a name (must be unique on the App Store, e.g. "Workout Log by Alex"), language, select your **bundle ID**, any SKU (e.g. `workoutlog1`).

**Upload a build**
1. In Xcode, set the device menu to **Any iOS Device (arm64)**.
2. Raise the build number for every upload: target → *General* → **Build** (1, 2, 3 …).
3. **Product → Archive**. When it finishes, the Organizer opens.
4. **Distribute App → App Store Connect → Upload** (accept defaults). The export-compliance question is already answered in the project (`ITSAppUsesNonExemptEncryption = NO`).
5. Wait for the e-mail saying the build has finished processing (usually 5–30 minutes).

**Invite friends**
1. App Store Connect → your app → **TestFlight** tab.
2. Left sidebar → **External Testing → +** → create a group, e.g. "Friends".
3. Add the build to the group and fill in *Test Information* (what to test, a feedback e-mail). The **first** build for external testers goes through a short Beta App Review (often within a day).
4. When approved, either **add testers by e-mail** or turn on a **Public Link** and send it in WhatsApp.
5. Friends install **TestFlight** from the App Store, open your link/e-mail → **Install**. Their data lives only on their own phone.

**Good to know**
- Each TestFlight build works for **90 days**; upload a new build (higher build number) before then. Later builds to the same group usually don't need a full review.
- *Internal Testing* (no review) is limited to people you add as users in your App Store Connect team — fine for 1–2 close friends, but external testing with a public link is simpler for a group.
- Updates installed through TestFlight keep everyone's data (it's stored in the app's container on their phone). Ask friends to **Export All Data** occasionally as a backup.

---

## 5. Where to tweak things
| What | Where |
|---|---|
| Progression step (2.5 kg / 5 lbs) | `WeightUnit.progressionStep` |
| Overload rule | `ProgressionService.overloadStatus` |
| Sample routines | `SampleDataService.seed` |
| Chime sound | `Haptics.restFinished` (system sound 1007) |
| Accent color / icon | `Assets.xcassets` |
| Rest step / limits | `RestTime` in `WeightUnit.swift` |
