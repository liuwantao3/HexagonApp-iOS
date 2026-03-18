import SwiftUI
import AVFoundation

struct StoryDetailView: View {
    let story: Story
    
    @State private var isPlaying = false
    @State private var player: AVPlayer?
    @State private var fullStory: Story?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentSentenceIndex = 0
    @State private var sentences: [String] = []
    @State private var displayTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showDebug = false
    
    private let apiService = APIService()
    
    private let baseWordsPerMinute: Double = 100
    
    private var effectiveWordsPerMinute: Double {
        let speedFactor = fullStory?.voiceSpeed ?? story.voiceSpeed ?? 1.0
        return baseWordsPerMinute * speedFactor
    }
    
    var body: some View {
        VStack(spacing: 0) {
            storyScrollView
            if showDebug {
                debugOverlay
                    .padding(.horizontal)
            }
            audioControlBar
        }
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(showDebug ? "Hide Debug" : "Debug") {
                    showDebug.toggle()
                }
            }
        }
        .task {
            await loadFullStory()
            prepareSentences()
        }
        .onDisappear {
            stopAudio()
        }
    }
    
    // MARK: - Story Scroll View
    private var storyScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                storyImage
                storyMetadata
                storyContent
                progressIndicator
            }
            .padding(.bottom, 120)
        }
    }
    
    // MARK: - Story Image
    private var storyImage: some View {
        let displayUrl = fullStory?.fullImageUrl ?? story.fullImageUrl
        return AsyncImage(url: displayUrl) { phase in
            switch phase {
            case .empty:
                if displayUrl != nil {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 250)
                        .overlay(ProgressView())
                }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 250)
                    .clipped()
            case .failure:
                Rectangle()
                    .fill(Color.red.opacity(0.1))
                    .frame(height: 250)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            @unknown default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Metadata
    private var storyMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                metadataTag(text: fullStory?.genre ?? story.genre, isPrimary: true)
                metadataTag(text: fullStory?.difficulty ?? story.difficulty, isPrimary: false)
                if let length = fullStory?.length ?? story.length {
                    metadataTag(text: length, isPrimary: false)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func metadataTag(text: String, isPrimary: Bool) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isPrimary ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(16)
    }
    
    // MARK: - Story Content with Highlighting
    private var storyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                sentenceRow(index: index, sentence: sentence)
            }
        }
        .padding(.horizontal)
    }
    
    private func sentenceRow(index: Int, sentence: String) -> some View {
        let isHighlighted = index == currentSentenceIndex
        
        return Text(sentence)
            .font(.body)
            .fontWeight(isHighlighted ? .semibold : .regular)
            .foregroundColor(isHighlighted ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHighlighted ? Color.blue : Color.clear)
            .cornerRadius(6)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(isHighlighted ? Color.blue.opacity(0.15) : Color.clear)
            .cornerRadius(8)
            .animation(.easeInOut(duration: 0.3), value: currentSentenceIndex)
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        Group {
            if isPlaying && !sentences.isEmpty {
                HStack {
                    Text("Sentence \(currentSentenceIndex + 1) of \(sentences.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(displayTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var debugOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG")
                .font(.caption.bold())
                .foregroundColor(.red)
            Text("Time: \(String(format: "%.2f", displayTime))s")
            Text("Current Index: \(currentSentenceIndex)")
            Text("Using Timestamps: \((fullStory?.sentenceTimestamps ?? story.sentenceTimestamps) != nil ? "YES" : "NO")")
            if let timestamps = fullStory?.sentenceTimestamps ?? story.sentenceTimestamps {
                Text("Timestamp Count: \(timestamps.count)")
                if currentSentenceIndex < timestamps.count {
                    let ts = timestamps[currentSentenceIndex]
                    Text("Current: \"\(ts.text.prefix(30))...\"")
                    Text("Start: \(String(format: "%.2f", ts.startTime))s, End: \(String(format: "%.2f", ts.endTime))s")
                }
            } else {
                Text("Using WPM estimation")
            }
        }
        .font(.caption.monospaced())
        .foregroundColor(.white)
        .padding(8)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Audio Control Bar
    private var audioControlBar: some View {
        Group {
            if fullStory?.hasAudio == true || story.hasAudio {
                VStack(spacing: 8) {
                    Divider()
                    
                    if isPlaying || displayTime > 0 {
                        progressBar
                    }
                    
                    controlButtons
                }
                .padding(.bottom, 16)
                .background(Color(.systemBackground))
            }
        }
    }
    
    private var progressBar: some View {
        ProgressView(value: displayTime, total: totalDuration)
            .progressViewStyle(LinearProgressViewStyle())
            .padding(.horizontal)
    }
    
    private var controlButtons: some View {
        HStack {
            Spacer()
            
            Button(action: restartAudio) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
            .padding(.trailing, 20)
            
            Button(action: toggleAudio) {
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentColor)
                    
                    Text(isPlaying ? "Pause" : "Play Audio")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Calculations
    private var totalDuration: TimeInterval {
        let content = fullStory?.content ?? story.content ?? ""
        let wordCount = content.split(separator: " ").count
        return TimeInterval(wordCount) / effectiveWordsPerMinute * 60
    }
    
    private func prepareSentences() {
        let timestamps = fullStory?.sentenceTimestamps ?? story.sentenceTimestamps
        
        if let timestamps = timestamps, !timestamps.isEmpty {
            sentences = timestamps.map { $0.text }
        } else {
            let content = fullStory?.content ?? story.content ?? ""
            let sentenceEndings = CharacterSet(charactersIn: ".!?\n")
            let parts = content.components(separatedBy: sentenceEndings)
            
            sentences = parts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }
    
    private func loadFullStory() async {
        isLoading = true
        do {
            fullStory = try await apiService.fetchStory(id: story.id)
            prepareSentences()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func toggleAudio() {
        if isPlaying {
            pauseAudio()
        } else {
            playAudio()
        }
    }
    
    private func playAudio() {
        guard let audioUrl = fullStory?.fullAudioUrl ?? story.fullAudioUrl else { return }
        
        if let player = player {
            player.play()
            isPlaying = true
            startTimer()
        } else {
            self.player = AVPlayer(url: audioUrl)
            self.player?.play()
            isPlaying = true
            startTimer()
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: self.player?.currentItem,
                queue: .main
            ) { _ in
                stopAudio()
            }
        }
    }
    
    private func pauseAudio() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    private func restartAudio() {
        player?.seek(to: .zero)
        displayTime = 0
        currentSentenceIndex = 0
        if !isPlaying {
            playAudio()
        }
    }
    
    private func stopAudio() {
        player?.pause()
        player = nil
        isPlaying = false
        stopTimer()
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateCurrentSentence()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentSentence() {
        guard let player = player else { return }
        
        displayTime = player.currentTime().seconds
        
        let timestamps = fullStory?.sentenceTimestamps ?? story.sentenceTimestamps
        
        let newIndex: Int
        if let timestamps = timestamps, !timestamps.isEmpty {
            newIndex = timestamps.lastIndex { $0.startTime <= displayTime } ?? 0
        } else {
            let timePerSentence = totalDuration / Double(max(sentences.count, 1))
            newIndex = min(Int(displayTime / timePerSentence), sentences.count - 1)
        }
        
        if newIndex != currentSentenceIndex && newIndex >= 0 {
            currentSentenceIndex = newIndex
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        StoryDetailView(story: Story(
            id: 1,
            title: "Sample Story",
            content: "Once upon a time, there was a little rabbit. He lived in a beautiful forest. One day, he met a wise old owl. The owl taught him an important lesson. They became good friends. The end.",
            genre: "fantasy",
            topic: "magic",
            difficulty: "beginner",
            length: "short",
            status: "published",
            createdAt: "2024-01-01",
            updatedAt: "2024-01-01",
            audioUrl: nil,
            imageUrl: nil,
            voiceSpeed: 1.0,
            sentenceTimestamps: nil
        ))
    }
}
