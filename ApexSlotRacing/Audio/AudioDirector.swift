import AppKit
import AVFoundation
import Foundation

enum MusicMode {
    case menu
    case race
    case final
}

final class AudioDirector: NSObject {
    static let shared = AudioDirector()

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    private let playerMotorStore = MotorParameterStore()
    private let opponentMotorStore = MotorParameterStore()
    private let playerMotorMixer = AVAudioMixerNode()
    private let opponentMotorMixer = AVAudioMixerNode()
    private let sfxMixer = AVAudioMixerNode()
    private let musicMixer = AVAudioMixerNode()
    private let playerMotorSource: AVAudioSourceNode
    private let opponentMotorSource: AVAudioSourceNode
    private var sfxPlayers: [AVAudioPlayerNode] = []
    private var sfxIndex = 0
    private let menuMusicPlayer = AVAudioPlayerNode()
    private let raceMusicPlayer = AVAudioPlayerNode()
    private var sfxBuffers: [SFXKind: AVAudioPCMBuffer] = [:]
    private var menuMusicBuffer: AVAudioPCMBuffer?
    private var raceMusicBuffer: AVAudioPCMBuffer?
    private var settings = AppSettings.default
    private var muted = false
    private var isRunning = false
    private var wantedActive = false
    private var musicMode: MusicMode = .menu
    private var buffersAreReady = false

    private override init() {
        playerMotorSource = MotorSynth.makeNode(format: format, store: playerMotorStore)
        opponentMotorSource = MotorSynth.makeNode(format: format, store: opponentMotorStore)
        super.init()
        configureGraph()
        installObservers()
        generateAssets()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        engine.stop()
    }

    private func configureGraph() {
        engine.attach(playerMotorSource)
        engine.attach(opponentMotorSource)
        engine.attach(playerMotorMixer)
        engine.attach(opponentMotorMixer)
        engine.attach(sfxMixer)
        engine.attach(musicMixer)

        engine.connect(playerMotorSource, to: playerMotorMixer, format: format)
        engine.connect(opponentMotorSource, to: opponentMotorMixer, format: format)
        engine.connect(playerMotorMixer, to: engine.mainMixerNode, format: format)
        engine.connect(opponentMotorMixer, to: engine.mainMixerNode, format: format)
        engine.connect(sfxMixer, to: engine.mainMixerNode, format: format)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: format)

        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: sfxMixer, format: format)
            sfxPlayers.append(player)
        }

        engine.attach(menuMusicPlayer)
        engine.attach(raceMusicPlayer)
        engine.connect(menuMusicPlayer, to: musicMixer, format: format)
        engine.connect(raceMusicPlayer, to: musicMixer, format: format)

        applyVolumes()
    }

    private func installObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidResignActive() {
        if isRunning {
            engine.pause()
            isRunning = false
        }
    }

    @objc private func appDidBecomeActive() {
        if wantedActive {
            start()
        }
    }

    func apply(settings: AppSettings) {
        self.settings = settings
        applyVolumes()
    }

    func start() {
        wantedActive = true
        guard !isRunning else { return }
        engine.prepare()
        do {
            try engine.start()
            isRunning = true
            for player in sfxPlayers { player.play() }
            scheduleMusicIfNeeded()
        } catch {
            NSLog("ApexSlotRacing: audio engine unavailable: \(error.localizedDescription)")
        }
    }

    func stop() {
        wantedActive = false
        playerMotorStore.set(speed: 0, throttle: 0, active: false)
        opponentMotorStore.set(speed: 0, throttle: 0, active: false)
        if isRunning {
            engine.stop()
            isRunning = false
        }
    }

    func setMuted(_ value: Bool) {
        muted = value
        applyVolumes()
    }

    var isMuted: Bool { muted }

    func pauseForGame() {
        if isRunning {
            engine.pause()
            isRunning = false
        }
    }

    func resumeForGame() {
        if wantedActive {
            start()
        }
    }

    func beginRace() {
        start()
        setMusicMode(.race)
    }

    func endRace() {
        playerMotorStore.set(speed: 0, throttle: 0, active: false)
        opponentMotorStore.set(speed: 0, throttle: 0, active: false)
        setMusicMode(.menu)
    }

    func setMusicMode(_ mode: MusicMode) {
        musicMode = mode
        scheduleMusicIfNeeded()
    }

    func setTension(_ value: Double) {
        let clamped = Float(max(0, min(1, value)))
        raceMusicPlayer.volume = 0.78 + clamped * 0.22
    }

    func updateMotor(index: Int, speed: Float, throttle: Float, active: Bool) {
        if index == 0 {
            playerMotorStore.set(speed: speed, throttle: throttle, active: active)
        } else {
            opponentMotorStore.set(speed: speed, throttle: throttle, active: active)
        }
    }

    func play(_ kind: SFXKind) {
        guard isRunning, buffersAreReady, let buffer = sfxBuffers[kind], !sfxPlayers.isEmpty else { return }
        let player = sfxPlayers[sfxIndex % sfxPlayers.count]
        sfxIndex += 1
        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    func countdown(_ value: Int) {
        play(value <= 0 ? .go : .countdown)
    }

    private func applyVolumes() {
        let master = muted ? 0 : Float(max(0, min(1, settings.masterVolume)))
        engine.mainMixerNode.outputVolume = master
        musicMixer.outputVolume = Float(max(0, min(1, settings.musicVolume)))
        sfxMixer.outputVolume = Float(max(0, min(1, settings.sfxVolume)))
        playerMotorMixer.outputVolume = Float(max(0, min(1, settings.engineVolume)))
        opponentMotorMixer.outputVolume = Float(max(0, min(1, settings.engineVolume))) * 0.75
    }

    private func scheduleMusicIfNeeded() {
        guard isRunning, buffersAreReady else { return }
        menuMusicPlayer.stop()
        raceMusicPlayer.stop()

        switch musicMode {
        case .menu:
            guard let menuMusicBuffer else { return }
            menuMusicPlayer.volume = 0.9
            menuMusicPlayer.scheduleBuffer(menuMusicBuffer, at: nil, options: .loops, completionHandler: nil)
            menuMusicPlayer.play()
        case .race, .final:
            guard let raceMusicBuffer else { return }
            raceMusicPlayer.volume = musicMode == .final ? 1.0 : 0.82
            raceMusicPlayer.scheduleBuffer(raceMusicBuffer, at: nil, options: .loops, completionHandler: nil)
            raceMusicPlayer.play()
        }
    }

    private func generateAssets() {
        let localFormat = format
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var generatedSFX: [SFXKind: AVAudioPCMBuffer] = [:]
            for kind in SFXKind.allCases {
                if let buffer = SFXSynth.makeBuffer(for: kind, format: localFormat) {
                    generatedSFX[kind] = buffer
                }
            }
            let menu = MusicSynth.makeLoop(format: localFormat, intensity: 0.45)
            let race = MusicSynth.makeLoop(format: localFormat, intensity: 0.92)

            DispatchQueue.main.async {
                guard let self else { return }
                self.sfxBuffers = generatedSFX
                self.menuMusicBuffer = menu
                self.raceMusicBuffer = race
                self.buffersAreReady = true
                self.scheduleMusicIfNeeded()
            }
        }
    }
}
