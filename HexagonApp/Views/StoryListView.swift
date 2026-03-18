import SwiftUI

struct StoryListView: View {
    @State private var stories: [Story] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStory: Story?
    
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
                            Task { await loadStories() }
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
                        await loadStories()
                    }
                }
            }
            .navigationTitle("Stories")
            .task {
                await loadStories()
            }
        }
    }
    
    private func loadStories() async {
        isLoading = true
        errorMessage = nil
        
        do {
            stories = try await apiService.fetchStories()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
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
