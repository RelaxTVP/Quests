//
//  QuestReminderApp.swift
//  QuestReminder
//
//  Created by Miguel Carretas on 10/02/2026.
//

import SwiftUI

@main
struct QuestReminderApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @StateObject private var purchaseManager = PurchaseManager.shared

    private var selectedAppearance: ColorScheme? {
        AppearanceMode(rawValue: appearanceMode)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(selectedAppearance)
                .environmentObject(purchaseManager)
                .task {
                    await QuestNotificationManager.requestAuthorizationIfNeeded()
                }
        }
    }
}
