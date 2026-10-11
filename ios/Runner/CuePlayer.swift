import AVFoundation
import MediaPlayer

/// Plays a list of cues at exact times.
///
/// The same contract as the Android engine, and the same rule: it knows
/// nothing about workouts, rounds or rest. It is handed "say this, that many
/// milliseconds from now" and it says it. All of the thinking stays in Dart.
///
/// How it survives the screen going off is where the two platforms part. There
/// is no foreground service here. iOS keeps an app alive in the background
/// while it is *playing audio*, so this one genuinely is: a silence buffer
/// loops on its own node for the whole session, and the cues are mixed over
/// it. That is a continuous stream rather than a trick, which matters both for
/// staying alive and for being honest about why the app asks for the audio
/// background mode.
///
/// The timing is better than Android's for free. Cues are scheduled on the
/// audio clock by sample, not by a handler against a millisecond clock, so
/// they land where they were put.
final class CuePlayer {
    static let shared = CuePlayer()

    private let renderer = PhraseRenderer()
    private let engine = AVAudioEngine()
    private let cueNode = AVAudioPlayerNode()
    private let silenceNode = AVAudioPlayerNode()

    /// Everything is converted to one format so a single node can play all of
    /// it. The synthesiser's own format varies by voice and device.
    private let format = AVAudioFormat(
        standardFormatWithSampleRate: 44100, channels: 1
    )!

    private var buffers: [String: AVAudioPCMBuffer] = [:]

    /// The list it was handed, kept so the session can be held and picked up
    /// again without Dart — the lock screen's buttons outlive the UI.
    private var cues: [(at: Int, key: String)] = []

    /// Sample time of cue zero, the anchor everything is measured from.
    private var startSample: AVAudioFramePosition = 0
    private var active = false
    private var pausedAt: Int?
    private var totalMs = 0
    private var countingUp = false
    private var title = "Workout"
    private var detail = ""

    /// Told to Dart as cues play and when the lock screen is used.
    var onFired: ((String) -> Void)?
    var onStopped: (() -> Void)?
    var onPaused: ((Bool) -> Void)?

    // MARK: - Session

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    /// `.mixWithOthers` rather than ducking, and that is a known trade-off:
    /// cues play over music at full volume instead of dipping it. Ducking on
    /// iOS lasts as long as the session is active, and the session has to stay
    /// active for the whole workout — so ducking here would leave music quiet
    /// for twenty minutes rather than for a word.
    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    private func startEngine() throws {
        guard !engine.isRunning else { return }

        if cueNode.engine == nil {
            engine.attach(cueNode)
            engine.attach(silenceNode)
            engine.connect(cueNode, to: engine.mainMixerNode, format: format)
            engine.connect(silenceNode, to: engine.mainMixerNode, format: format)
        }
        try engine.start()

        // A tenth of a second of nothing, on a loop, for as long as the
        // session lasts. This is what keeps the app alive between cues.
        if let silence = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate / 10)
        ) {
            silence.frameLength = silence.frameCapacity
            silenceNode.scheduleBuffer(silence, at: nil, options: .loops)
        }
        silenceNode.play()
        cueNode.play()
    }

    // MARK: - The contract

    var isAvailable: Bool { renderer.isAvailable }

    func warm(_ phrases: [String: String], completion: @escaping ([String]) -> Void) {
        renderer.render(phrases) { failed in
            let rendered = phrases.keys.filter { !failed.contains($0) }
            for key in rendered where self.buffers[key] == nil {
                self.buffers[key] = self.loadBuffer(self.renderer.file(for: key))
            }
            completion(failed)
        }
    }

    /// Arms the whole list and starts the session. Returns the elapsed time it
    /// was anchored at, which is always zero — Dart only needs to know it
    /// worked.
    @discardableResult
    func schedule(
        cues: [(at: Int, key: String)],
        leadMs: Int,
        title: String,
        detail: String,
        countUp: Bool
    ) -> Int {
        clearScheduled()

        self.cues = cues
        self.title = title
        self.detail = detail
        countingUp = countUp
        totalMs = cues.map(\.at).max() ?? 0
        pausedAt = nil

        do {
            try activateSession()
            try startEngine()
        } catch {
            return 0
        }

        guard let now = cueNode.lastRenderTime, now.isSampleTimeValid else {
            return 0
        }
        startSample = now.sampleTime + frames(forMs: leadMs)
        active = true

        arm(from: 0)
        updateNowPlaying()
        return 0
    }

    /// Posts every cue from [elapsed] onwards, on the audio clock.
    private func arm(from elapsedMs: Int) {
        for cue in cues where cue.at >= elapsedMs {
            guard let buffer = buffers[cue.key] else { continue }
            let at = AVAudioTime(
                sampleTime: startSample + frames(forMs: cue.at),
                atRate: format.sampleRate
            )
            cueNode.scheduleBuffer(buffer, at: at, options: []) { [weak self] in
                DispatchQueue.main.async { self?.onFired?(cue.key) }
            }
        }
    }

    /// Holds the session where it is: the cues stop, the clock stops, and the
    /// audio session stays up so there is something to come back to.
    func pause() {
        guard active, pausedAt == nil else { return }
        pausedAt = elapsedMs() ?? 0
        cueNode.stop()
        cueNode.play() // ready to be scheduled into again
        updateNowPlaying()
        onPaused?(true)
    }

    func resume() {
        guard let from = pausedAt else { return }
        pausedAt = nil
        guard let now = cueNode.lastRenderTime, now.isSampleTimeValid else { return }
        // Re-anchor so the clock picks up where it stopped rather than where
        // it would have been.
        startSample = now.sampleTime - frames(forMs: from)
        arm(from: from)
        updateNowPlaying()
        onPaused?(false)
    }

    func cancel() {
        clearScheduled()
        active = false
        pausedAt = nil
        cues = []
        silenceNode.stop()
        if engine.isRunning { engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
        clearNowPlaying()
    }

    func describe(title: String, detail: String) {
        self.title = title
        self.detail = detail
        if active { updateNowPlaying() }
    }

    /// How long the session has been running, or nil when there is none.
    func elapsedMs() -> Int? {
        guard active else { return nil }
        if let held = pausedAt { return held }
        guard let now = cueNode.lastRenderTime, now.isSampleTimeValid else { return 0 }
        let elapsed = Int(
            Double(now.sampleTime - startSample) / format.sampleRate * 1000
        )
        return max(0, elapsed)
    }

    func isPaused() -> Bool { active && pausedAt != nil }

    // MARK: - Lock screen

    /// The iOS answer to Android's notification: the system's own playback
    /// controls, on the lock screen and in Control Centre.
    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: detail,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(elapsedMs() ?? 0) / 1000,
            MPNowPlayingInfoPropertyPlaybackRate: pausedAt == nil ? 1.0 : 0.0,
        ]
        if !countingUp { info[MPMediaItemPropertyPlaybackDuration] = Double(totalMs) / 1000 }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        let centre = MPRemoteCommandCenter.shared()
        centre.playCommand.isEnabled = true
        centre.pauseCommand.isEnabled = true
        centre.stopCommand.isEnabled = true
        centre.playCommand.removeTarget(nil)
        centre.pauseCommand.removeTarget(nil)
        centre.stopCommand.removeTarget(nil)
        centre.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        centre.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        centre.stopCommand.addTarget { [weak self] _ in
            self?.cancel()
            self?.onStopped?()
            return .success
        }
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Interruptions

    /// A phone call must not end the workout. iOS stops the audio either way;
    /// this holds the session so it can be picked up rather than lost.
    @objc private func handleInterruption(_ note: Notification) {
        guard
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init) ?? []
            if options.contains(.shouldResume) {
                try? activateSession()
                try? startEngine()
                resume()
            }
        @unknown default:
            break
        }
    }

    // MARK: - Helpers

    private func clearScheduled() {
        cueNode.stop()
        if engine.isRunning { cueNode.play() }
    }

    private func frames(forMs ms: Int) -> AVAudioFramePosition {
        AVAudioFramePosition(Double(ms) / 1000 * format.sampleRate)
    }

    /// Reads a rendered phrase and converts it to the one format the cue node
    /// plays, because the synthesiser's own format varies by voice and device
    /// and a node plays exactly one.
    private func loadBuffer(_ url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let source = file.processingFormat
        guard let input = AVAudioPCMBuffer(
            pcmFormat: source, frameCapacity: AVAudioFrameCount(file.length)
        ), (try? file.read(into: input)) != nil else { return nil }

        if source == format { return input }

        guard let converter = AVAudioConverter(from: source, to: format) else {
            return nil
        }
        let ratio = format.sampleRate / source.sampleRate
        guard let output = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(Double(input.frameLength) * ratio) + 1024
        ) else { return nil }

        var done = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if done {
                status.pointee = .noDataNow
                return nil
            }
            done = true
            status.pointee = .haveData
            return input
        }
        return error == nil ? output : nil
    }
}
