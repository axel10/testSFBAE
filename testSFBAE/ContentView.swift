//
//  ContentView.swift
//  testSFBAE
//
//  Created by axel10 on 2026/5/22.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var vm = PlayerViewModel()
    @State private var showFileImporter = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hue: 0.62, saturation: 0.72, brightness: 0.18),
                    Color(hue: 0.72, saturation: 0.68, brightness: 0.10),
                    Color(hue: 0.82, saturation: 0.60, brightness: 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Bar
                topBar

                // Main content split: album art + queue
                HStack(spacing: 0) {
                    // Left: Now Playing panel
                    nowPlayingPanel
                        .frame(width: 360)

                    Divider()
                        .background(Color.white.opacity(0.08))

                    // Right: Queue panel
                    queuePanel
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [
                .audio,
                UTType(filenameExtension: "mp3") ?? .audio,
                UTType(filenameExtension: "flac") ?? .audio,
                UTType(filenameExtension: "aiff") ?? .audio,
                UTType(filenameExtension: "wav") ?? .audio,
                UTType(filenameExtension: "m4a") ?? .audio,
                UTType(filenameExtension: "ogg") ?? .audio,
                UTType(filenameExtension: "opus") ?? .audio,
                UTType(filenameExtension: "ape") ?? .audio,
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                let securedURLs = urls.compactMap { url -> URL? in
                    guard url.startAccessingSecurityScopedResource() else { return nil }
                    return url
                }
                vm.addTracks(securedURLs)
            case .failure:
                break
            }
        }
        .alert("Playback Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .frame(minWidth: 750, minHeight: 520)
        .preferredColorScheme(.dark)
    }

    // MARK: - Top Bar

    var topBar: some View {
        HStack {
            Label("Nebula Player", systemImage: "waveform.circle.fill")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                )

            Spacer()

            // Volume
            HStack(spacing: 8) {
                Image(systemName: vm.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                Slider(value: Binding(
                    get: { vm.volume },
                    set: { vm.setVolume($0) }
                ), in: 0...1)
                .frame(width: 90)
                .tint(.purple.opacity(0.8))
            }
            .padding(.trailing, 4)

            // Add files button
            Button {
                showFileImporter = true
            } label: {
                Label("Add Files", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Now Playing Panel

    var nowPlayingPanel: some View {
        VStack(spacing: 0) {
            // Album Art
            albumArtView
                .padding(.top, 28)
                .padding(.horizontal, 28)

            // Track Info
            VStack(spacing: 6) {
                Text(vm.currentTrack?.title ?? "No track selected")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.25), value: vm.currentTrack?.title)

                Text(vm.currentTrack?.artist ?? "—")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.25), value: vm.currentTrack?.artist)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Progress Slider
            progressSection
                .padding(.horizontal, 24)

            Spacer(minLength: 12)

            // Controls
            controlButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
    }

    // MARK: - Album Art

    var albumArtView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.72, saturation: 0.55, brightness: 0.35),
                            Color(hue: 0.62, saturation: 0.60, brightness: 0.22),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let art = vm.currentTrack?.albumArt {
                Image(nsImage: art)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
        .frame(width: 280, height: 280)
        .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 12)
        .scaleEffect(vm.isPlaying ? 1.0 : 0.95)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: vm.isPlaying)
    }

    // MARK: - Progress Section

    var progressSection: some View {
        VStack(spacing: 6) {
            // Progress slider
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 5)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * vm.progress, height: 5)

                    // Draggable thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .purple.opacity(0.6), radius: 4)
                        .offset(x: max(0, geo.size.width * vm.progress - 7))
                }
                .frame(height: 14)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            vm.isDraggingSlider = true
                            let newProgress = min(max(value.location.x / geo.size.width, 0), 1)
                            vm.progress = newProgress
                            if vm.totalTime > 0 {
                                vm.currentTime = newProgress * vm.totalTime
                            }
                        }
                        .onEnded { value in
                            let newProgress = min(max(value.location.x / geo.size.width, 0), 1)
                            vm.seek(to: newProgress)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                vm.isDraggingSlider = false
                            }
                        }
                )
            }
            .frame(height: 14)

            // Time labels
            HStack {
                Text(timeString(vm.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(timeString(vm.totalTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Control Buttons

    var controlButtons: some View {
        HStack(spacing: 32) {
            // Previous
            Button {
                vm.playPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 22))
                    .foregroundColor(vm.hasPrevious ? .white : .white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(!vm.hasPrevious && vm.currentTime <= 3.0)
            .scaleEffect(vm.hasPrevious || vm.currentTime > 3.0 ? 1.0 : 0.85)
            .animation(.easeInOut(duration: 0.15), value: vm.hasPrevious)

            // Play / Pause
            Button {
                vm.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, Color(hue: 0.60, saturation: 0.85, brightness: 0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)
                        .shadow(color: .purple.opacity(0.5), radius: 12, x: 0, y: 6)

                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .offset(x: vm.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(vm.queue.isEmpty ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: vm.isPlaying)

            // Next
            Button {
                vm.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 22))
                    .foregroundColor(vm.hasNext ? .white : .white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(!vm.hasNext)
            .scaleEffect(vm.hasNext ? 1.0 : 0.85)
            .animation(.easeInOut(duration: 0.15), value: vm.hasNext)
        }
    }

    // MARK: - Queue Panel

    var queuePanel: some View {
        VStack(spacing: 0) {
            // Queue header
            HStack {
                Text("Queue")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("\(vm.queue.count) tracks")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04))

            if vm.queue.isEmpty {
                emptyQueuePlaceholder
            } else {
                List {
                    ForEach(Array(vm.queue.enumerated()), id: \.element.id) { index, track in
                        QueueRowView(
                            track: track,
                            index: index,
                            isCurrentTrack: index == vm.currentIndex,
                            isPlaying: vm.isPlaying && index == vm.currentIndex
                        )
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(index == vm.currentIndex
                                      ? Color.purple.opacity(0.18)
                                      : Color.clear)
                                .padding(.vertical, 2)
                        )
                        .listRowSeparator(.hidden)
                        .onTapGesture {
                            vm.playTrack(at: index)
                        }
                    }
                    .onMove(perform: vm.moveTrack)
                    .onDelete(perform: { indexSet in
                        indexSet.sorted(by: >).forEach { vm.removeTrack(at: $0) }
                    })
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    var emptyQueuePlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.white.opacity(0.18))
            Text("No tracks in queue")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
            Text("Click \"Add Files\" to open audio files")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.2))
            Button {
                showFileImporter = true
            } label: {
                Label("Add Files", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.purple.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSec = Int(seconds)
        let min = totalSec / 60
        let sec = totalSec % 60
        return String(format: "%d:%02d", min, sec)
    }
}

// MARK: - Queue Row View

struct QueueRowView: View {
    let track: Track
    let index: Int
    let isCurrentTrack: Bool
    let isPlaying: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Track number / waveform icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCurrentTrack
                          ? Color.purple.opacity(0.3)
                          : Color.white.opacity(0.07))
                    .frame(width: 38, height: 38)

                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                        .symbolEffect(.variableColor.iterative.reversing)
                } else if isCurrentTrack {
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundColor(.purple.opacity(0.9))
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Title & artist
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 13, weight: isCurrentTrack ? .semibold : .regular))
                    .foregroundColor(isCurrentTrack ? .white : .white.opacity(0.8))
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            // Album art thumbnail
            if let art = track.albumArt {
                Image(nsImage: art)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered && !isCurrentTrack
                      ? Color.white.opacity(0.06)
                      : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .frame(width: 800, height: 540)
}
