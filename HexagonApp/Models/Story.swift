import Foundation

struct SentenceTimestamp: Codable {
    let text: String
    let startTime: Double
    let endTime: Double
    
    enum CodingKeys: String, CodingKey {
        case text
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

struct Story: Codable, Identifiable {
    let id: Int
    let title: String
    let content: String?
    let genre: String
    let topic: String
    let difficulty: String
    let length: String?
    let status: String?
    let createdAt: String
    let updatedAt: String
    let audioUrl: String?
    let imageUrl: String?
    let voiceSpeed: Double?
    let sentenceTimestamps: [SentenceTimestamp]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, genre, topic, difficulty, length, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case audioUrl = "audio_url"
        case imageUrl = "image_url"
        case voiceSpeed = "voice_speed"
        case sentenceTimestamps = "sentence_timestamps"
    }
    
    private var serverBase: String {
        "http://localhost:3000"
    }
    
    // Full URLs with server base
    var fullImageUrl: URL? {
        guard let imageUrl = imageUrl else { return nil }
        if imageUrl.hasPrefix("http") {
            return URL(string: imageUrl)
        }
        return URL(string: serverBase + imageUrl)
    }
    
    var fullAudioUrl: URL? {
        guard let audioUrl = audioUrl else { return nil }
        if audioUrl.hasPrefix("http") {
            return URL(string: audioUrl)
        }
        return URL(string: serverBase + audioUrl)
    }
    
    var hasAudio: Bool {
        return fullAudioUrl != nil
    }
    
    var hasImage: Bool {
        return fullImageUrl != nil
    }
}

struct StoriesResponse: Codable {
    let stories: [Story]
    let pagination: Pagination
}

struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}
