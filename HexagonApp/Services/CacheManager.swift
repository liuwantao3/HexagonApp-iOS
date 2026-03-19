import Foundation

class CacheManager {
    private let storiesKey = "cached_stories"
    private let lastUpdatedKey = "stories_last_updated"
    private let lastSyncedKey = "stories_last_synced"
    
    func saveStories(_ stories: [Story]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(stories) {
            UserDefaults.standard.set(encoded, forKey: storiesKey)
            UserDefaults.standard.set(Date(), forKey: lastSyncedKey)
        }
    }
    
    func loadStories() -> [Story]? {
        guard let data = UserDefaults.standard.data(forKey: storiesKey) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([Story].self, from: data)
    }
    
    func getLastSynced() -> Date? {
        return UserDefaults.standard.object(forKey: lastSyncedKey) as? Date
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: storiesKey)
        UserDefaults.standard.removeObject(forKey: lastSyncedKey)
    }
}
