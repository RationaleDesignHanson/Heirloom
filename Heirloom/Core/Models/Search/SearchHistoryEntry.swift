//
//  SearchHistoryEntry.swift
//  Heirloom
//
//  Phase 7 Enhanced: Search history model
//  Tracks recent user searches
//

import Foundation

struct SearchHistoryEntry: Codable, Identifiable {
    let id: String
    let query: String
    let filters: SearchFilters?
    let timestamp: Date

    init(query: String, filters: SearchFilters? = nil) {
        self.id = UUID().uuidString
        self.query = query
        self.filters = filters
        self.timestamp = Date()
    }
}
