//
//  SettingsPage.swift
//  Superstar (macOS)
//
//  Created by Jordi Bruin on 26/07/2022.
//

import Foundation

enum SettingsPage: String, Hashable, Identifiable, CaseIterable {
    case home
    case credentials
    case suggestions
    case support
    case settings
//    case iap
    
    var id: String { self.rawValue }
    
    var label: some View {
        switch self {
        case .home:
            return Label("Home", systemImage: "house.fill")
        case .settings:
            return Label("Settings", systemImage: "gearshape.fill")
        case .credentials:
            return Label("Credentials", systemImage: "key.fill")
        case .suggestions:
            return Label("Suggestions", systemImage: "star.bubble")
        case .support:
            return Label("Support", systemImage: "questionmark.circle.fill")
//        case .iap:
//            return Label("Supernova", systemImage: "star.fill")
        }
    }
    
    @ViewBuilder
    var destination: some View {
        switch self {
        case .home:
            EmptyStateView()
        case .settings:
            SettingsSheet()
        case .credentials:
            AddCredentialsView()
        case .suggestions:
            SuggestionsConfigView()
        case .support:
            SupportScreen()
//        case .iap:
//            Supernova()
        }
    }
}
