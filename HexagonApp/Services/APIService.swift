import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)
}

struct SyncResponse: Codable {
    let hasUpdates: Bool
    let newCount: Int
    let latestUpdate: String?
    let serverTime: String
}

class APIService {
    static let baseURL = "http://localhost:3000/api"
    
    private let cacheManager = CacheManager()
    
    func fetchStories(page: Int = 1, limit: Int = 20) async throws -> [Story] {
        guard let url = URL(string: "\(APIService.baseURL)/stories/mobile?page=\(page)&limit=\(limit)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError(0)
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            let storiesResponse = try decoder.decode(StoriesResponse.self, from: data)
            return storiesResponse.stories
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func checkForUpdates(lastSync: Date?) async throws -> SyncResponse {
        guard let url = URL(string: "\(APIService.baseURL)/stories/mobile/sync\(lastSync != nil ? "?since=\(ISO8601DateFormatter().string(from: lastSync!))" : "")") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError(0)
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(SyncResponse.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func fetchStory(id: Int) async throws -> Story {
        guard let url = URL(string: "\(APIService.baseURL)/stories/mobile/\(id)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError(0)
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(Story.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func getCachedStories() -> [Story]? {
        return cacheManager.loadStories()
    }
    
    func cacheStories(_ stories: [Story]) {
        cacheManager.saveStories(stories)
    }
    
    func getLastSyncTime() -> Date? {
        return cacheManager.getLastSynced()
    }
}
