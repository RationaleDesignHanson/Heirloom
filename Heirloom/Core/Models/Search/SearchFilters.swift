//
//  SearchFilters.swift
//  Heirloom
//
//  Phase 7 Enhanced: Search filter model
//  Filters for location and specialties
//

import Foundation

struct SearchFilters: Codable {
    var location: String?
    var specialties: [String]?

    var isActive: Bool {
        location != nil || !(specialties?.isEmpty ?? true)
    }

    init(location: String? = nil, specialties: [String]? = nil) {
        self.location = location
        self.specialties = specialties
    }
}
