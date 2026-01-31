//
//  SearchFiltersSheet.swift
//  Heirloom
//
//  Phase 7 Enhanced: Search filters UI
//  Filter users by location and specialties
//

import SwiftUI

struct SearchFiltersSheet: View {
    @Binding var filters: SearchFilters
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLocation: String = ""
    @State private var selectedSpecialties: Set<String> = []

    private let availableSpecialties = [
        "Italian", "Mexican", "Asian", "Baking",
        "Grilling", "Vegan", "Vegetarian", "Seafood",
        "Desserts", "Soups", "Salads", "Pasta"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("City or region", text: $selectedLocation)
                }

                Section("Specialties") {
                    ForEach(availableSpecialties, id: \.self) { specialty in
                        Toggle(specialty, isOn: Binding(
                            get: { selectedSpecialties.contains(specialty) },
                            set: { isSelected in
                                if isSelected {
                                    selectedSpecialties.insert(specialty)
                                } else {
                                    selectedSpecialties.remove(specialty)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyFilters()
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button("Clear All") {
                        selectedLocation = ""
                        selectedSpecialties = []
                    }
                }
            }
            .onAppear {
                selectedLocation = filters.location ?? ""
                selectedSpecialties = Set(filters.specialties ?? [])
            }
        }
    }

    private func applyFilters() {
        filters.location = selectedLocation.isEmpty ? nil : selectedLocation
        filters.specialties = selectedSpecialties.isEmpty ? nil : Array(selectedSpecialties)
        dismiss()
    }
}
