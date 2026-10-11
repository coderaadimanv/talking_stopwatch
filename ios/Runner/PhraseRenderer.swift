import AVFoundation

/// Turns phrases into audio files, once, using the phone's own voice.
///
/// The same bargain as on Android, for the same reason. Speaking a cue at the
/// moment it is due does not work: the speech synthesiser takes an
/// unpredictable moment to start, which is enough to land "three" after the
/// phase it was counting down has already changed. So nothing is ever spoken
/// live — every phrase is rendered to a file ahead of time and played from
/// there, where the only delay left is the audio path itself and it is the
/// same every time.
///
/// Files are named by the key Dart computed for the text and kept in caches:
/// losing them costs one re-render, not any user data.
final class PhraseRenderer {
    private let synthesiser = AVSpeechSynthesizer()

    private lazy var directory: URL = {
        let caches = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        )[0]
        let folder = caches.appendingPathComponent("phrases", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true
        )
        return folder
    }()

    func file(for key: String) -> URL {
        directory.appendingPathComponent("\(key).caf")
    }

    private func isRendered(_ key: String) -> Bool {
        let path = file(for: key).path
        let size = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int
        return (size ?? 0) > 0
    }

    /// Whether this device has a voice to render with.
    var isAvailable: Bool {
        !AVSpeechSynthesisVoice.speechVoices().isEmpty
    }

    /// Renders every phrase that is not already cached, then calls back with
    /// the keys it could not render.
    ///
    /// Awaited by Dart before a session starts, so the first "go" never waits
    /// on the speech engine. Already-cached phrases cost nothing.
    func render(
        _ phrases: [String: String],
        completion: @escaping ([String]) -> Void
    ) {
        dropCacheIfVoiceChanged()

        let todo = phrases.filter { !isRendered($0.key) }
        guard !todo.isEmpty else { return completion([]) }

        // One at a time. AVSpeechSynthesizer.write hands back buffers for a
        // single utterance, and overlapping them would interleave the audio.
        DispatchQueue.global(qos: .userInitiated).async {
            var failed: [String] = []
            for (key, text) in todo where !self.write(text, to: self.file(for: key)) {
                failed.append(key)
            }
            DispatchQueue.main.async {
                self.trimCache()
                completion(failed)
            }
        }
    }

    /// Writes one utterance to one file, and waits for it.
    private func write(_ text: String, to url: URL) -> Bool {
        try? FileManager.default.removeItem(at: url)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice.speechVoices().first

        var output: AVAudioFile?
        var failed = false
        let finished = DispatchSemaphore(value: 0)

        synthesiser.write(utterance) { buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer else {
                failed = true
                finished.signal()
                return
            }
            // The synthesiser signals the end with an empty buffer, and emits
            // empty ones along the way that must not be written.
            if pcm.frameLength == 0 {
                finished.signal()
                return
            }
            do {
                if output == nil {
                    output = try AVAudioFile(
                        forWriting: url,
                        settings: pcm.format.settings,
                        commonFormat: pcm.format.commonFormat,
                        interleaved: pcm.format.isInterleaved
                    )
                }
                try output?.write(from: pcm)
            } catch {
                failed = true
                finished.signal()
            }
        }

        // Generous: this only ever runs on a first render, behind a screen
        // that says it is getting ready.
        if finished.wait(timeout: .now() + 10) == .timedOut { failed = true }
        output = nil
        return !failed && isRenderedFile(url)
    }

    private func isRenderedFile(_ url: URL) -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
        return (size ?? 0) > 0
    }

    /// The cached files are only good for the voice that made them, so the
    /// voice in use is stamped beside them and the cache dropped when it
    /// changes. Dart's cache keys know nothing about voices, which is
    /// deliberate — this is the only place that has to care.
    private func dropCacheIfVoiceChanged() {
        let stamp = directory.appendingPathComponent("voice.txt")
        let voice = AVSpeechSynthesisVoice(language: "en-US")
        let now = "\(voice?.identifier ?? "none")|\(voice?.language ?? "?")"

        if let previous = try? String(contentsOf: stamp, encoding: .utf8),
           previous == now {
            return
        }
        for file in (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? [] where file.pathExtension == "caf" {
            try? FileManager.default.removeItem(at: file)
        }
        try? now.write(to: stamp, atomically: true, encoding: .utf8)
    }

    /// Keeps the cache small enough to ignore: oldest files go first.
    private func trimCache(limit: Int = 5 * 1024 * 1024) {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys
        ).filter({ $0.pathExtension == "caf" }) else { return }

        func size(_ url: URL) -> Int {
            (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        func modified(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
        }

        var total = files.reduce(0) { $0 + size($1) }
        guard total > limit else { return }
        for file in files.sorted(by: { modified($0) < modified($1) }) {
            if total <= limit { break }
            total -= size(file)
            try? FileManager.default.removeItem(at: file)
        }
    }
}
