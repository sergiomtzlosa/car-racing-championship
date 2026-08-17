import Foundation

struct HelpSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [String]
}

struct HelpTopic: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let summary: String
    let sections: [HelpSection]
    let tip: String
}

enum HelpContent {
    static let topics: [HelpTopic] = [
        HelpTopic(
            id: "quickStart",
            title: "Quick Start",
            icon: "flag.checkered",
            summary: "From the garage to the grid in four steps. Career progress saves automatically.",
            sections: [
                HelpSection(id: "quickStart.choose",
                            title: "Choose an event",
                            items: [
                                "Quick Race — pick a circuit, car, difficulty, lap count and environment.",
                                "Pursuit — choose fugitive or pursuer and use siren boost to escape or capture.",
                                "Championship — create a 2–8 driver season and race qualifying plus one heat per round.",
                                "Track Editor and Garage are always available from the Main Menu."
                            ]),
                HelpSection(id: "quickStart.race",
                            title: "Race",
                            items: [
                                "Wait for the three-light countdown, then hold throttle.",
                                "Use the on-screen pedals with the mouse if you do not have a keyboard or gamepad.",
                                "Press Esc or P to pause, and R to restart at any time.",
                                "Results are recorded when you cross the finish; open Results to review every split."
                            ]),
                HelpSection(id: "quickStart.help",
                            title: "Help and settings",
                            items: [
                                "Open this handbook from Help → Apex Slot Racing Help or with Command-?.",
                                "The Main Menu footer also has a HELP button.",
                                "Audio, visuals, controller defaults, Cloud AI and local-data reset live in Settings."
                            ])
            ],
            tip: "The local AI is always running underneath. An optional cloud driver can suggest throttle and brake, but a disconnected network never interrupts a race."
        ),
        HelpTopic(
            id: "controls",
            title: "Race Controls",
            icon: "keyboard.fill",
            summary: "Keyboard, gamepad and mouse controls available during every race.",
            sections: [
                HelpSection(id: "controls.keyboard",
                            title: "Keyboard",
                            items: [
                                "Throttle — W / ↑ / Space",
                                "Brake — S / ↓",
                                "Camera cycle — C (Cockpit → Chase → Cinematic)",
                                "Pursuit boost — Shift",
                                "Pause or resume — Esc / P",
                                "Restart race — R",
                                "Mute audio — M"
                            ]),
                HelpSection(id: "controls.gamepad",
                            title: "Gamepad",
                            items: [
                                "Throttle — right trigger",
                                "Brake — left trigger",
                                "Boost — A",
                                "Camera cycle — Y",
                                "Restart — X",
                                "Pause — Menu"
                            ]),
                HelpSection(id: "controls.screen",
                            title: "Screen controls",
                            items: [
                                "The race HUD exposes press-and-hold throttle and brake pedals.",
                                "The pursuit boost button appears when a boost charge is available.",
                                "The camera button cycles the same three views as C."
                            ])
            ],
            tip: "Gamepads are discovered automatically. If no controller is connected, keyboard and mouse remain active."
        ),
        HelpTopic(
            id: "driving",
            title: "Driving & Penalties",
            icon: "gauge.with.dots.needle.67percent",
            summary: "Slot cars stay on their lane, but too much speed through a corner will deslot them.",
            sections: [
                HelpSection(id: "driving.corners",
                            title: "Cornering",
                            items: [
                                "Release throttle and tap brake before sharp curves.",
                                "The safe speed depends on curvature, car stability and surface.",
                                "Exceeding the car's margin triggers a deslot, a tumble animation and a three-second penalty.",
                                "The car respawns at the start of the piece where it crashed; respawns never count as laps."
                            ]),
                HelpSection(id: "driving.loop",
                            title: "Loops and bridges",
                            items: [
                                "The vertical loop has a minimum speed; enter with enough throttle to stay attached.",
                                "Bridges and crossovers are ordinary racing surface, but they change the camera view significantly.",
                                "Cinematic camera is the easiest way to inspect bridge and loop geometry."
                            ]),
                HelpSection(id: "driving.pursuit",
                            title: "Pursuit rules",
                            items: [
                                "The fugitive receives a short head start.",
                                "The pursuer has three siren-boost charges; each charge gives a brief speed surge.",
                                "The pursuer wins by closing to capture distance within three laps.",
                                "The fugitive wins by surviving to the finish."
                            ])
            ],
            tip: "Smooth is fast. A clean line through a curve usually beats braking late and losing three seconds to a deslot."
        ),
        HelpTopic(
            id: "modes",
            title: "Game Modes",
            icon: "trophy.fill",
            summary: "Three ways to race, plus persistent records and unlock progression.",
            sections: [
                HelpSection(id: "modes.quick",
                            title: "Quick Race",
                            items: [
                                "Player versus CPU on any built-in or custom circuit.",
                                "Choose car, difficulty, 3 / 5 / 10 laps and the club, dusk or night environment.",
                                "Best laps and win records update the local profile."
                            ]),
                HelpSection(id: "modes.pursuit",
                            title: "Pursuit",
                            items: [
                                "Fugitive versus pursuer over three laps.",
                                "Choose your role before the race and use boost strategically.",
                                "Pursuit wins count toward the local profile and Game Center when available."
                            ]),
                HelpSection(id: "modes.championship",
                            title: "Championship",
                            items: [
                                "A persistent season across the four built-in circuits.",
                                "Qualifying seeds two-car heats; the player drives their heat and the remaining AI heats are simulated.",
                                "Points go to the top four overall: 10 / 6 / 4 / 2.",
                                "Wins, podiums and best laps break ties. The champion unlocks the open-wheel car."
                            ])
            ],
            tip: "Completed championship seasons stay on the profile. Start a new season from the Championship screen when you are ready."
        ),
        HelpTopic(
            id: "editor",
            title: "Track Editor",
            icon: "square.grid.3x3.fill",
            summary: "Build a closed circuit, validate it and test drive it before saving.",
            sections: [
                HelpSection(id: "editor.build",
                            title: "Building",
                            items: [
                                "Start from the starter oval or a blank layout.",
                                "Add pieces from the palette; pieces append to the open connector automatically.",
                                "Replace or mirror the selected piece in the inspector, and use Undo / Redo freely.",
                                "Watch the gap warning — a circuit must close before it can be saved or raced."
                            ]),
                HelpSection(id: "editor.validate",
                            title: "Validation and test drive",
                            items: [
                                "Validate reports the gap and heading diagnostics for the open connector.",
                                "Auto Close adds tangent-continuous link curves and straights.",
                                "Generated link pieces remain editable and can be undone.",
                                "Test Drive runs the unsaved layout without changing career statistics."
                            ]),
                HelpSection(id: "editor.files",
                            title: "Saving and sharing",
                            items: [
                                "Save custom circuits to Application Support/ApexSlotRacing/Tracks.",
                                "Export or import a circuit as JSON from the toolbar.",
                                "A valid circuit has exactly one start/finish piece, at least one piece and a closed path."
                            ])
            ],
            tip: "Build in short sections and validate often. Auto Close is easiest when the final connector already points roughly back toward the start."
        ),
        HelpTopic(
            id: "garage",
            title: "Garage & Unlocks",
            icon: "wrench.and.screwdriver.fill",
            summary: "Tune the look of every car and unlock new machines and liveries.",
            sections: [
                HelpSection(id: "garage.cars",
                            title: "Cars",
                            items: [
                                "The GT car is available from the start.",
                                "Win any race to unlock the 80s Rally car.",
                                "Win a championship to unlock the Open Wheel car.",
                                "Handling and stability differ between models; choose the car that suits the circuit."
                            ]),
                HelpSection(id: "garage.livery",
                            title: "Paint and livery",
                            items: [
                                "Change body paint, rim style and decal set in the Garage.",
                                "Changes persist in the local profile and appear on track.",
                                "Livery sets unlock through podiums and wins.",
                                "The turntable stops when Reduce Motion is enabled in Settings."
                            ]),
                HelpSection(id: "garage.saving",
                            title: "Saving and previewing",
                            items: [
                                "Press Save Configuration to write paint, wheel and decal choices to your local profile.",
                                "Randomize previews a new combination; nothing is saved until you press Save Configuration.",
                                "Drag the showcase to orbit the car, and pause or resume the turntable with the showcase control.",
                                "Reduce Motion in Settings stops the turntable automatically."
                            ])
            ],
            tip: "Unlock All in Settings is a testing shortcut. Reset All Local Data returns the profile and garage to their initial state."
        ),
        HelpTopic(
            id: "settings",
            title: "Settings & Data",
            icon: "slider.horizontal.3",
            summary: "Audio, visuals, Cloud AI, Game Center and the local save reset.",
            sections: [
                HelpSection(id: "settings.audio",
                            title: "Audio and visuals",
                            items: [
                                "Master, music, effects and motor volumes are independent.",
                                "Quality presets control MSAA and scene detail.",
                                "Show frame statistics displays the SceneKit renderer overlay.",
                                "Reduce Motion disables camera drift, turntable spin and cockpit shake."
                            ]),
                HelpSection(id: "settings.camera",
                            title: "Camera and controls",
                            items: [
                                "Choose the default race camera: Cockpit, Chase or Cinematic.",
                                "Camera switching during a race does not change the saved default."
                            ]),
                HelpSection(id: "settings.cloud",
                            title: "Cloud AI",
                            items: [
                                "Direct JSON posts telemetry to a /v1/drive endpoint.",
                                "OpenAI-compatible posts a chat request to /v1/chat/completions.",
                                "The API token is stored in the macOS Keychain, not in UserDefaults.",
                                "OpenCode Zen endpoint and free-model presets are available in the Cloud AI panel.",
                                "The local mock endpoint exercises the OpenAI protocol offline."
                            ]),
                HelpSection(id: "settings.data",
                            title: "Game Center and data",
                            items: [
                                "Sign In / Refresh authenticates Game Center; Dashboard opens the native leaderboard view.",
                                "When Game Center is unavailable, records remain local.",
                                "Reset All Local Data removes the profile, custom tracks, championship and settings.",
                                "Built-in content is never removed."
                            ])
            ],
            tip: "Only HTTPS endpoints and loopback HTTP endpoints are accepted. Cloud AI always fails soft to the local driver."
        )
    ]

    static func topic(id: String) -> HelpTopic {
        topics.first(where: { $0.id == id }) ?? topics[0]
    }
}
