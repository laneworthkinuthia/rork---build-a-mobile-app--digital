//
//  CardexApp.swift
//  Cardex
//

import SwiftUI
import UIKit

@main
struct CardexApp: App {
    @State private var auth = AuthManager()

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
        }
    }

    /// Keeps the tab bar and navigation chrome on the graphite canvas instead of
    /// the default translucent system grey.
    private func configureAppearance() {
        let canvas = UIColor(red: 0x0D / 255, green: 0x0D / 255, blue: 0x0F / 255, alpha: 1)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = canvas.withAlphaComponent(0.92)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = canvas
        navAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }
}
