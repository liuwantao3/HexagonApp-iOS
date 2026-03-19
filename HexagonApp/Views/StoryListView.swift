import SwiftUI

struct StoryListView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var stories: [Story] = []
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var selectedStory: Story?
    @State private var hasNewContent = false
    
    private let apiService = APIService()
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && stories.isEmpty {
                    ProgressView("Loading...")
                } else if let error = errorMessage, stories.isEmpty {
                    VStack(spacing: 16) {
                        Text("Error loading stories")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task { await syncStories() }
                        }
                    }
                } else if stories.isEmpty {
                    Text("No stories yet")
                        .foregroundColor(.secondary)
                } else {
                    List(stories) { story in
                        NavigationLink(destination: StoryDetailView(story: story)) {
                            StoryRowView(story: story)
                        }
                    }
                    .refreshable {
                        await syncStories()
                    }
                }
            }
            .navigationTitle("Stories")
            .overlay(alignment: .top) {
                if hasNewContent && !isSyncing {
                    newContentBanner
                }
            }
            .task {
                await initializeStories()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task { await checkForUpdatesQuietly() }
                }
            }
        }
    }
    
    private var newContentBanner: some View {
        HStack {
            Image(systemName: "sparkles")
            Text("New stories available")
                .font(.caption)
            Spacer()
            Button("Refresh") {
                Task { await syncStories() }
            }
            .font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange)
    }
    
    private func initializeStories() async {
        if let cachedStories = apiService.getCachedStories(), !cachedStories.isEmpty {
            stories = cachedStories
        }
        
        isLoading = stories.isEmpty
        
        await checkForUpdatesAndSync()
        
        isLoading = false
    }
    
    private func checkForUpdatesAndSync() async {
        isSyncing = true
        
        do {
            let syncResponse = try await apiService.checkForUpdates(lastSync: apiService.getLastSyncTime())
            hasNewContent = syncResponse.hasUpdates
            
            if syncResponse.hasUpdates {
                await syncStories()
            }
        } catch {
            await syncStories()
        }
        
        isSyncing = false
    }
    
    private func checkForUpdatesQuietly() async {
        guard !isSyncing else { return }
        
        do {
            let syncResponse = try await apiService.checkForUpdates(lastSync: apiService.getLastSyncTime())
            hasNewContent = syncResponse.hasUpdates
            
            if syncResponse.hasUpdates {
                await syncStories()
            }
        } catch {
            // Silent fail for background sync
        }
    }
    
    private func syncStories() async {
        do {
            let newStories = try await apiService.fetchStories()
            stories = newStories
            apiService.cacheStories(newStories)
            hasNewContent = false
        } catch {
            if stories.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct StoryRowView: View {
    let story: Story
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: story.fullImageUrl) { phase in
                switch phase {
                case .empty:
                    if story.hasImage {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView())
                    } else {
                        Image(systemName: "book.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .overlay(
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                        )
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(story.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("\(story.genre) • \(story.difficulty)\(story.length.map { " • \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Audio indicator
            if story.hasAudio {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StoryListView()
}
