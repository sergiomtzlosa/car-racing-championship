# Apex Slot Racing

A native macOS 3D slot-car championship built with Swift, SwiftUI, SceneKit, AVFoundation, GameKit and Network.framework. The entire visual and audio presentation is procedural: track pieces, cars, paint, textures, the hobby-room diorama, and the soundtrack are generated in code at runtime.

The game is designed as a premium offline single-player experience, with optional Game Center leaderboards/achievements and an optional external cloud-AI driver. Local AI is always underneath the cloud layer, so the race never depends on the network.

> **Trademark note:** Apex Slot Racing is an independent game inspired by classic 1:32 slot racing. It does not use Scalextric branding, logos, track-system trade dress or third-party art/audio assets.

---

## Requirements

| Item | Version |
|---|---|
| macOS | 14.0 or newer |
| Xcode | 16+ (tested with Xcode 27.2) |
| Swift toolchain | Swift 6 compiler, Swift 5 language mode |
| Project generator | [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46+ |
| Hardware | Apple Silicon recommended; Metal-capable Mac required |

Install XcodeGen if necessary:

```bash
brew install xcodegen
```

---

## Quick start

From the repository root:

```bash
xcodegen generate
open ApexSlotRacing.xcodeproj
```

Build and run without a signing team:

```bash
xcodebuild \
  -project ApexSlotRacing.xcodeproj \
  -scheme ApexSlotRacing \
  -configuration Debug \
  -derivedDataPath build \
  build

open build/Build/Products/Debug/ApexSlotRacing.app
```

The generated `ApexSlotRacing.xcodeproj` is committed so the project can be opened without running XcodeGen first. Regenerate it after adding/removing source files or changing `project.yml`.

**No development team is required.** `project.yml` explicitly sets `CODE_SIGNING_ALLOWED = NO`, `CODE_SIGNING_REQUIRED = NO` and `CODE_SIGN_STYLE = Manual`, so opening the project in Xcode and pressing Run does not produce the “requires a development team” error. For a signed/distribution build, re-enable signing with your team:

```bash
xcodebuild \
  -project ApexSlotRacing.xcodeproj \
  -scheme ApexSlotRacing \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=YOURTEAMID \
  build
```

---

## Controls

### Keyboard

| Action | Keys |
|---|---|
| Throttle | `W` / `↑` / `Space` |
| Brake | `S` / `↓` |
| Camera cycle (Cockpit → Chase → Cinematic) | `C` |
| Pursuit boost | `Shift` |
| Pause / resume | `Esc` / `P` |
| Restart race | `R` |
| Mute audio | `M` |

### Gamepad

| Action | Control |
|---|---|
| Throttle | Right trigger |
| Brake | Left trigger |
| Boost | A |
| Camera cycle | Y |
| Restart | X |
| Pause | Menu |

Gamepads are discovered automatically. The race HUD also has press-and-hold throttle/brake controls and a boost button for mouse-only play.

---

## Game modes

### Quick Race
Player vs CPU on any built-in or custom circuit. Choose a car, difficulty, lap count (3 / 5 / 10), and environment. A three-second countdown locks the throttle until the lights go green.

### Pursuit
Fugitive vs pursuer. The player chooses a role. The fugitive receives a short head start; the pursuer has three siren-boost charges. The pursuer wins by closing to capture distance within three laps; the fugitive wins by surviving.

### Championship
A persistent 2–8-driver season across the four built-in circuits. Qualifying seeds two-car heats. The player drives their heat; the remaining AI heats are simulated deterministically. Points are awarded to the top four overall (10 / 6 / 4 / 2), with wins, podiums and best laps as tie-breakers. The champion unlocks the open-wheel car.

### Track Editor
A 3D circuit editor with:

- Starter-oval and blank templates
- Piece palette, auto-append placement, rotate and mirror
- Open-connector feedback and a live gap warning
- Detailed validation report with gap and heading diagnostics
- Auto Close adds tangent-continuous link curves/straights; generated link pieces remain editable and undoable
- Undo/redo
- Test drive on the unsaved layout
- Save/load custom circuits
- JSON export/import through a file panel or paste sheet

### Garage
Three-handling-distinct cars with procedural bodies, PBR paint and clear coat, wheels/rims, glasses, lights, decals and visible livery changes. Paint, rim style and decal set changes persist in the local profile and appear in races.

### Settings
Audio mix, graphics quality, camera default, frame statistics, reduced motion, cloud-AI endpoint/test, Game Center sign-in/dashboard, unlock-all testing shortcut and local-data reset.

---

## Architecture

```
ApexSlotRacing/
├── App/            App lifecycle, routing, commands
├── Core/
│   ├── Track/      Editor model and track mutation helpers
│   ├── Race/       Fixed-step simulation, AI, lap timing
│   ├── Championship/ Season, heats, standings, qualifying
│   ├── Persistence/ Atomic JSON stores and track file I/O
│   ├── TrackModels.swift, TrackPath.swift, TrackPathBuilder.swift
│   └── TrackCatalog.swift
├── Scene/          SceneKit factory, camera rig, input, editor viewport
├── UI/             SwiftUI screens, HUD, shared components, theme
├── Audio/          AVAudioEngine motor synth, SFX, procedural music
├── Services/       Game Center, cloud AI, network, haptics, achievements
├── Resources/      Icon assets, asset catalog, reference track JSON
└── Support/        Info.plist and entitlements
```

### Simulation

- Cars are constrained to their lane spline and advance by arc length.
- Fixed timestep: 120 Hz, with a clamped accumulator and render interpolation.
- Longitudinal model: motor force, drag, rolling resistance, gravity on ramps/loops.
- Cornering safety is derived from horizontal lane curvature. Bridge ramps and the vertical loop are excluded from lateral-grip curvature; the loop has its own minimum-speed rule.
- Exceeding the safe speed by the car's margin triggers a deslot, a tumble animation, a three-second penalty and a piece-start respawn.
- Lap progress is tracked from a validated closed path; respawns never count as laps.

### Cameras

- **Cockpit**: hood/cockpit camera at the car's driver anchor, wider FOV and subtle shake.
- **Chase**: spring-damped follower that looks ahead into corners.
- **Cinematic**: elevated orthographic diorama view.
- Camera switches are available during a race and are reflected in the HUD.

### Determinism

AI mistake rolls use a seeded generator per race. The simulation clock and the fixed step are independent of render frame rate. AI-vs-AI championship heats use the same core model without rendering.

---

## Data and persistence

User data lives in Application Support:

```
~/Library/Application Support/ApexSlotRacing/
├── profile.json
├── championship.json
├── records.json (reserved for records migration)
├── Tracks/
│   └── <UUID>.json
```

When the app is signed with the App Sandbox entitlement, macOS redirects this path into the app container:

```
~/Library/Containers/com.sid.ApexSlotRacing/Data/Library/Application Support/ApexSlotRacing/
```

Settings are stored in `UserDefaults` under `apexSlotRacing.settings.v1`. All JSON writes are atomic. Track and championship schema versions are checked during import.

### Track JSON schema

```json
{
  "schemaVersion": 1,
  "id": "11111111-1111-1111-1111-111111111111",
  "name": "My Circuit",
  "laneCount": 2,
  "environment": "dusk",
  "pieces": [
    {
      "id": "A1B2C3D4-0000-0000-0000-000000000001",
      "kind": "startFinish",
      "length": 6,
      "mirrored": false
    },
    {
      "id": "A1B2C3D4-0000-0000-0000-000000000002",
      "kind": "curveWide90",
      "length": 5,
      "radius": 3,
      "mirrored": false
    }
  ],
  "createdAt": "2026-01-01T12:00:00Z",
  "updatedAt": "2026-01-01T12:00:00Z",
  "isBuiltIn": false
}
```

Fields:

| Field | Notes |
|---|---|
| `schemaVersion` | Currently `1` |
| `id` | Stable UUID for custom tracks |
| `laneCount` | Always 2 in this release |
| `pieces[].kind` | `startFinish`, `straightLong`, `straightShort`, `curveSharp90`, `curveWide90`, `curveWide180`, `curve45`, `closureArc`, `chicane`, `crossover`, `bridge`, `loop360` |
| `pieces[].length` | Optional override; otherwise the catalog default |
| `pieces[].radius` | Optional override for curves |
| `pieces[].arcSweep` | Optional sweep angle in radians for generated `closureArc` pieces |
| `pieces[].mirrored` | Mirrors the local piece profile |
| `pieces[].position` / `pieces[].rotationY` | Optional legacy/editor metadata; the path builder assembles pieces in array order |
| `environment` | `club`, `dusk`, `night` |
| `isBuiltIn` | Imported tracks are forced to `false` |

The four files in `ApexSlotRacing/Resources/Tracks/` are reference copies of the built-in circuits. The runtime source of truth for built-ins is `TrackCatalog`; the JSON copies are useful as import fixtures and editor examples.

A valid imported circuit must contain exactly one `startFinish` piece, have at least one piece, close within the path tolerance, and be long enough to race. Import errors are presented as friendly messages in the editor.

---

## App icon

The user-facing file is **`AppIcon.icns`**, not `.ocns` (which is not a valid Apple icon container). The icon pipeline includes:

- `Tools/make-icon.swift` — CoreGraphics/AppKit master renderer
- `Tools/make-icon.sh` — iconset + `iconutil` pipeline
- `ApexSlotRacing/Resources/AppIcon.icns` — app bundle icon
- `ApexSlotRacing/Resources/Assets.xcassets/AppIcon.appiconset/` — asset catalog entries

Regenerate everything:

```bash
./Tools/make-icon.sh
xcodegen generate
```

Validate:

```bash
sips -g pixelWidth -g pixelHeight ApexSlotRacing/Resources/AppIcon.icns
iconutil -c iconset ApexSlotRacing/Resources/AppIcon.icns -o /tmp/AppIcon.iconset
```

The built app contains the full 16–1024 px `Contents/Resources/AppIcon.icns` as an explicit target resource. `ASSETCATALOG_COMPILER_APPICON_NAME` is intentionally set to an empty string so Xcode's asset compiler does not overwrite that full icon with a device-thinned version; the `AppIcon.appiconset` remains in the catalog as a reusable source of icon sizes.

---

## Game Center setup

Game Center is optional. Without a paid team / App Store Connect configuration, the app logs an authentication failure once at launch and continues with **local records active**. No gameplay feature is blocked.

To enable it:

1. Set `PRODUCT_BUNDLE_IDENTIFIER` to your App Store Connect bundle ID (the template uses `com.sid.ApexSlotRacing`).
2. Re-enable code signing (`CODE_SIGNING_ALLOWED=YES`), set your Development Team, and enable the **Game Center** capability in Xcode. The entitlements already request `com.apple.developer.game-center`.
3. Create the leaderboards and achievements in App Store Connect with the IDs below.
4. Sign in with a Game Center sandbox account on the test Mac.
5. Run a race and use **Settings → Game Center → Sign In / Refresh** to authenticate.

Identifiers used by the app:

| Type | Identifier |
|---|---|
| Best lap | `apex.bestlap.sunset_speedway`, `apex.bestlap.harbor_hairpins`, `apex.bestlap.loop_360`, `apex.bestlap.night_grand_prix` |
| Championship | `apex.championship.points` |
| Pursuit | `apex.pursuit.wins` |
| Achievements | `apex.first.win`, `apex.flawless`, `apex.loop.master`, `apex.pursuit.master`, `apex.champion`, `apex.speed` |

Achievement progress and records remain available in `profile.json` regardless of Game Center availability. The dashboard button opens `GKGameCenterViewController` when authenticated; otherwise it retries authentication.

---

## Optional cloud AI

The local AI is authoritative. Cloud AI sends anonymous race telemetry at roughly 10 Hz and overlays a throttle/brake/target-speed prediction when available. The request has a 0.35-second timeout, ignores stale responses, and silently falls back to local control on network errors, invalid JSON or HTTP failure. No Game Center identity or personal data is sent.

Enable it in **Settings → Cloud AI** and supply an endpoint. The default local endpoint is:

```
http://127.0.0.1:8787/v1/drive
```

Only `https` endpoints and loopback `http` endpoints are accepted. This keeps the optional local demo from weakening the app's ATS policy.

### Mock server

The repository includes a standard-library-only mock:

```bash
python3 Tools/ai-mock-server.py --port 8787
```

Health check:

```bash
curl http://127.0.0.1:8787/health
```

Drive request:

```bash
curl -s -X POST http://127.0.0.1:8787/v1/drive \
  -H 'Content-Type: application/json' \
  -d '{
    "speed": 6.2,
    "maxSpeed": 9.2,
    "lookahead": [
      {"distance": 2.0, "curvature": 0.30},
      {"distance": 5.0, "curvature": 0.0}
    ]
  }'
```

Example response:

```json
{"throttle":0.2412,"brake":0.247,"targetSpeed":5.428,"confidence":0.9491}
```

Protocol summary:

```json
POST /v1/drive
{
  "sessionId": "UUID",
  "trackId": "loop_360",
  "difficulty": "medium",
  "speed": 8.4,
  "maxSpeed": 12.0,
  "opponentGap": 6.2,
  "boostAvailable": false,
  "lookahead": [
    {"distance": 2.0, "curvature": 0.01, "surface": "straight", "loop": false}
  ]
}
```

```json
200 OK
{"throttle":0.88,"brake":0.0,"targetSpeed":7.9,"confidence":0.92}
```

The mock server implements a conservative safe-speed heuristic and is intended for demonstration and QA. It is not required to play the game.

---

## Audio

All audio is synthesized at runtime with `AVAudioEngine`:

- Per-car electric-motor whine that tracks speed and throttle
- Tyre squeal, rail rumble, deslot crash, loop whoosh, boost and UI cues
- Procedural drums, bass, arpeggio and pad layers that crossfade for menu, race, final lap and victory
- Master/music/effects/motor volume controls and mute

The realtime source callbacks use lock-protected parameter snapshots and avoid Swift collection work on the audio render thread. If the audio engine fails to start, gameplay continues silently.

---

## Testing and verification

Run the full unit/smoke suite:

```bash
xcodegen generate
xcodebuild \
  -project ApexSlotRacing.xcodeproj \
  -scheme ApexSlotRacing \
  -configuration Debug \
  -derivedDataPath build \
  test
```

Covered areas include:

- Track piece transforms, closure, lane lengths and loop/bridge continuity
- Serialization/import-export round trips and validation failures
- Fixed-step physics, safe speed, deslot penalties and lap timing
- AI speed profiles and deterministic clean stints on all four reference tracks
- Championship creation, qualifying, heats, points, tie-breaks and persistence
- Audio synthesis smoke tests
- SceneKit world/car construction, offscreen rendering, and a full race-scene attach/render/teardown
- Every screen, sheet, HUD element and menu command through an in-process SwiftUI/AppKit accessibility harness (Main Menu, Quick Race/Pursuit setup, Garage, Track Editor including Validate/Auto Close/paste JSON, Settings, Championship setup/completion, Game Center fallback, race HUD, pause/finish overlays, Results)
- Snapshot renders of all screens and overlays at 1440×900 and 1180×760, including the Track Validation sheet at sheet size

The UI tests use a visible, retained test window and query the app's own accessibility tree, so they do not require macOS Automation Mode or a separate XCUITest runner. Test sessions disable live Game Center authentication to avoid system prompts; the shipping app still authenticates on launch. Native file/color panels and the Game Center dashboard are covered through their availability and service/action paths because they are system-owned UI.

Visual smoke snapshots are written to `/tmp/apex-*.png` by the scene tests for manual inspection, including `/tmp/apex-track-*-perspective.png` circuit overviews and the three `/tmp/apex-showcase-render*.png` garage models. Screen/overlay snapshots are written to `/tmp/apex-ui-audit-*.png`.

Release build:

```bash
xcodebuild \
  -project ApexSlotRacing.xcodeproj \
  -scheme ApexSlotRacing \
  -configuration Release \
  -derivedDataPath build \
  build
```

### Manual QA checklist

1. Launch, verify the Dock/Finder icon and the live 3D hero menu.
2. Quick Race on each built-in circuit; cycle Cockpit/Chase/Cinematic.
3. Deliberately overdrive a corner; confirm crash, three-second penalty and piece-start respawn.
4. Run the loop circuit and confirm the minimum-speed loop behavior.
5. Change paint/rim/livery in the Garage, quit, relaunch and confirm persistence.
6. Build a circuit in the Editor, test drive it, save it, export and re-import it.
7. Create a 2-driver and an 8-driver championship; run qualifying and a heat; confirm standings persistence.
8. Enable Cloud AI, run the mock server, test the connection, then stop the server mid-race and confirm the instant local fallback.
9. Launch unsigned; confirm the Game Center failure degrades to local records.
10. Resize/fullscreen the window and test keyboard/gamepad input.

---

## Signing and notarization

The project ships with code signing disabled so it builds and runs locally without any team or provisioning profile:

```yaml
CODE_SIGN_STYLE: Manual
CODE_SIGNING_ALLOWED: NO
CODE_SIGNING_REQUIRED: NO
```

To distribute a signed build:

1. Re-enable signing (`CODE_SIGNING_ALLOWED=YES`, `CODE_SIGN_STYLE=Automatic`) and configure your Development Team.
2. Keep the sandbox, user-selected files and network-client entitlements.
3. Add the Game Center capability if shipping leaderboards.
4. Archive with Xcode or `xcodebuild archive`.
5. Notarize the exported app and staple the ticket with `notarytool` / `stapler`.

Reverting to unsigned local play is just a matter of restoring `CODE_SIGNING_ALLOWED = NO`.

No server is required for offline play; the only network calls are optional Game Center and the user-configured cloud-AI endpoint.

---

## Performance notes

- Static track/environment geometry is merged by material in `TrackSceneBuilder`.
- Cars share procedural geometry recipes; repeated props use simple shared materials.
- Quality presets (`low`, `medium`, `high`, `ultra`) control MSAA, shadows and texture work.
- The simulation is decoupled from the render loop and never allocates in the update hot loop.
- If the frame budget is exceeded, lower the quality preset in Settings.

The target is 60 fps at 1440×900 with two cars and the full diorama on Apple Silicon. SceneKit is deprecated on newer macOS SDKs but remains available in the current toolchain; the rendering code is isolated so a future RealityKit or Metal migration can replace it without touching the simulation.

---

## Known limitations

- Offline single-player only; no real-time multiplayer or online lobby.
- Game Center requires App Store Connect identifiers and a signing team; the unsigned build intentionally runs local-only.
- Cloud AI is an optional overlay; the local AI is the guaranteed opponent.
- Built-in track layouts are defined in code. The JSON copies in `Resources/Tracks` are reference exports, not a hot-loading mod system.
- All art and audio are procedural; there are no high-detail USDZ or recorded audio assets bundled.
- AI-vs-AI championship heats are simulated; only the player's heat is rendered.
- The icon request's `.ocns` spelling is treated as a typo for the valid macOS `.icns` format.

---

## License / attribution

This is an independent, trademark-safe project. No Scalextric assets, logos, track-system trade dress, music or third-party models are included. The code and generated art are provided as a self-contained macOS game implementation.
