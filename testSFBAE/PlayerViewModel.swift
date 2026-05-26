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

    /// 标记队列是否已自然播完（区别于用户暂停）
    /// 源码关键：实现 audioPlayerEndOfAudio 后引擎不会自动 stop，
    /// 仍处于 Paused 状态，必须我们自己跟踪这个"结束"状态
    private var queueDidEnd: Bool = false

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
        queueDidEnd = false          // 重置结束标记
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
        // ✅ 队列播完 → 点播放 → 从第一首重新开始
        // 源码分析：实现了 audioPlayerEndOfAudio，引擎不会自动 stop，
        // 而是留在 Paused 状态（engineIsRunning=true, isPlaying=false）。
        // 因此不能用 player.isStopped 判断，要用自己的 queueDidEnd 标志。
        if queueDidEnd && !queue.isEmpty {
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
        // 如果队列已结束，先恢复播放再 seek（引擎处于 paused 状态）
        if queueDidEnd { return }
        let clamped = max(0.0, min(1.0, position))
        if clamped >= 0.999 {
            if hasNext {
                playNext()
            } else {
                _ = player.seek(position: 1.0)
                queueDidEnd = true
                isPlaying = false
                progress = 0
                currentTime = 0
            }
        } else {
            _ = player.seek(position: clamped)
        }
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

        // 只在非队列结束状态下同步 isPlaying
        // 防止 timer 轮询到引擎的 paused 状态覆盖 queueDidEnd=true 时的 isPlaying=false
        if !queueDidEnd {
            isPlaying = player.isPlaying
        }
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
            if let pic = meta.attachedPictures.first(where: { _ in true }) {
                albumArt = NSImage(data: pic.imageData)
            }
        }

        return Track(url: url, title: title, artist: artist, albumArt: albumArt)
    }
}

// MARK: - AudioPlayer.Delegate

extension PlayerViewModel: AudioPlayer.Delegate {

    /// 源码关键（AudioPlayer.mm 第 2138-2142 行）：
    /// 实现此方法后，shouldStop = false，引擎不会自动停止。
    /// 引擎仍处于 running+paused 状态，我们通过 queueDidEnd 标记来区分。
    nonisolated func audioPlayerEndOfAudio(_ audioPlayer: AudioPlayer) {
        Task { @MainActor in
            // 没有下一首 → 标记结束，显示播放按钮
            if self.hasNext {
                self.playNext()
            } else {
                self.queueDidEnd = true
                self.isPlaying = false
                // 重置进度到 0（视觉上显示完播状态）
                self.progress = 0
                self.currentTime = 0
            }
        }
    }

    nonisolated func audioPlayer(_ audioPlayer: AudioPlayer,
                                 playbackStateChanged playbackState: AudioPlayer.PlaybackState) {
        Task { @MainActor in
            // 只在非队列结束状态下响应状态变化，避免 paused 事件覆盖我们设置的 isPlaying=false
            if !self.queueDidEnd {
                self.isPlaying = (playbackState == .playing)
            }
        }
    }

    nonisolated func audioPlayer(_ audioPlayer: AudioPlayer, encounteredError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
}
