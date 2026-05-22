//
//  PlayerViewModel.swift
//  testSFBAE
//
//  Created by axel10 on 2026/5/22.
//

import SwiftUI
import Combine
import SFBAudioEngine

// MARK: - Track Model

struct Track: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var title: String
    var artist: String
    var albumArt: NSImage?

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - PlayerViewModel

@MainActor
class PlayerViewModel: NSObject, ObservableObject {

    // MARK: Published State

    @Published var queue: [Track] = []
    @Published var currentIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var totalTime: Double = 0
    @Published var progress: Double = 0
    @Published var isDraggingSlider: Bool = false
    @Published var errorMessage: String? = nil
    @Published var volume: Double = 1.0

    // MARK: Private

    private let player = AudioPlayer()
    private var timer: Timer?

    // MARK: Init

    override init() {
        super.init()
        player.delegate = self
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: Computed

    var currentTrack: Track? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var hasNext: Bool { currentIndex < queue.count - 1 }
    var hasPrevious: Bool { currentIndex > 0 }

    // MARK: Queue Management

    func addTracks(_ urls: [URL]) {
        let newTracks = urls.compactMap { url -> Track? in
            guard url.isFileURL else { return nil }
            return makeTrack(from: url)
        }
        let wasEmpty = queue.isEmpty
        queue.append(contentsOf: newTracks)

        // Auto-play first track if nothing playing
        if wasEmpty && !queue.isEmpty {
            playTrack(at: 0)
        }
    }

    func removeTrack(at index: Int) {
        guard index < queue.count else { return }
        queue.remove(at: index)
        if currentIndex >= queue.count {
            currentIndex = max(0, queue.count - 1)
        }
    }

    func moveTrack(from source: IndexSet, to destination: Int) {
        let currentID = currentTrack?.id
        queue.move(fromOffsets: source, toOffset: destination)
        if let id = currentID {
            currentIndex = queue.firstIndex(where: { $0.id == id }) ?? currentIndex
        }
    }

    func playTrack(at index: Int) {
        guard index < queue.count else { return }
        currentIndex = index
        let track = queue[index]
        do {
            try player.play(track.url)
            isPlaying = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Playback Controls

    func togglePlayPause() {
        // 队列播完后点播放 → 从第一首重新开始
        if player.isStopped && !queue.isEmpty {
            playTrack(at: 0)
            return
        }
        do {
            try player.togglePlayPause()
            isPlaying = player.isPlaying
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playNext() {
        guard hasNext else { return }
        playTrack(at: currentIndex + 1)
    }

    func playPrevious() {
        if currentTime > 3.0 {
            _ = player.seek(position: 0.0)
        } else if hasPrevious {
            playTrack(at: currentIndex - 1)
        }
    }

    func seek(to position: Double) {
        let clamped = max(0.0, min(1.0, position))
        _ = player.seek(position: clamped)
    }

    func setVolume(_ vol: Double) {
        volume = vol
        try? player.setVolume(Float(vol))
    }

    // MARK: Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    private func updateProgress() {
        guard !isDraggingSlider else { return }

        // Use positionAndTime for efficiency
        if let pt = player.positionAndTime {
            if let ct = pt.time.current {
                currentTime = ct
            }
            if let tt = pt.time.total {
                totalTime = tt
            }
            if let p = pt.position.progress {
                progress = p
            }
        }
        isPlaying = player.isPlaying
    }

    // MARK: Track Metadata Helper

    private func makeTrack(from url: URL) -> Track {
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var albumArt: NSImage? = nil

        if let audioFile = try? AudioFile(readingPropertiesAndMetadataFrom: url) {
            let meta = audioFile.metadata
            if let t = meta.title, !t.isEmpty { title = t }
            if let a = meta.artist, !a.isEmpty { artist = a }
            // attachedPictures is NSSet<AttachedPicture>
            if let pic = meta.attachedPictures.first(where: { _ in true }) {
                albumArt = NSImage(data: pic.imageData)
            }
        }

        return Track(url: url, title: title, artist: artist, albumArt: albumArt)
    }
}

// MARK: - AudioPlayer.Delegate

extension PlayerViewModel: AudioPlayer.Delegate {

    nonisolated func audioPlayerEndOfAudio(_ audioPlayer: AudioPlayer) {
        Task { @MainActor in
            if self.hasNext {
                self.playNext()
            } else {
                self.isPlaying = false
            }
        }
    }

    nonisolated func audioPlayer(_ audioPlayer: AudioPlayer,
                                 playbackStateChanged playbackState: AudioPlayer.PlaybackState) {
        Task { @MainActor in
            self.isPlaying = (playbackState == .playing)
        }
    }

    nonisolated func audioPlayer(_ audioPlayer: AudioPlayer, encounteredError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
}
