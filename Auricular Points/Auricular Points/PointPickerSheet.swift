//
//  PointPickerSheet.swift
//  Auricular Points
//
//  Created by Howard Ellenberger on 9/21/25.
//


import SwiftUI

// MARK: - Picker Sheet

struct PointPickerSheet: View {
    let points: [EarPoint]
    @Binding var searchText: String
    var onPick: (EarPoint) -> Void
    @Environment(\.dismiss) private var dismiss

    private var filtered: [EarPoint] {
        guard !searchText.isEmpty else { return points }
        return points.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.bodyPart.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \.id) { p in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.headline)
                        Text(p.bodyPart).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onPick(p); dismiss() }
                }
            }
            // List style differs by platform
            #if os(macOS)
            .listStyle(.inset)
            #else
            .listStyle(.insetGrouped)
            #endif

            // Search differs by platform (placement not on macOS)
            #if os(macOS)
            .searchable(text: $searchText, prompt: "Search points")
            #else
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search points")
            #endif

            .navigationTitle("Select Point")
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") { dismiss() }
                }
                #else
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
                #endif
            }
        }
    }
}
