//
//  SearchHistoryManager.swift
//  Heirloom
//
//  Phase 7 Enhanced: Search history persistence
//  Manages recent search queries in UserDefaults
//

import Foundation

@MainActor
class SearchHistoryManager: ObservableObject {
    @Published private(set) var recentSearches: [SearchHistoryEntry] = []

    private let maxHistoryItems = 10
    private let storageKey = "searchHistory"

    init() {
        loadHistory()
    }

    func addSearch(query: String, filters: SearchFilters? = nil) {
        // Don't add if query is empty or very short
        guard query.count >= 2 else { return }

        // Remove duplicate if exists
        recentSearches.removeAll { $0.query.lowercased() == query.lowercased() }

        // Add to beginning
        let entry = SearchHistoryEntry(query: query, filters: filters)
        recentSearches.insert(entry, at: 0)

        // Trim to max items
        if recentSearches.count > maxHistoryItems {
            recentSearches = Array(recentSearches.prefix(maxHistoryItems))
        }

        saveHistory()
    }

    func removeSearch(id: String) {
        recentSearches.removeAll { $0.id == id }
        saveHistory()
    }

    func clearAll() {
        recentSearches = []
        saveHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let history = try? JSONDecoder().decode([SearchHistoryEntry].self, from: data) else {
            return
        }
        recentSearches = history
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(recentSearches) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
