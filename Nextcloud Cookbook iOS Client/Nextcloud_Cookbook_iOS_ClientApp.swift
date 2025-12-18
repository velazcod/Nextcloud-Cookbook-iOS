//
//  Nextcloud_Cookbook_iOS_ClientApp.swift
//  Nextcloud Cookbook iOS Client
//
//  Created by Vincent Meilinger on 06.09.23.
//

import SwiftUI

@main
struct Nextcloud_Cookbook_iOS_ClientApp: App {
    @AppStorage("onboarding") var onboarding = true
    @AppStorage("language") var language = Locale.current.language.languageCode?.identifier ?? "en"

    /// URL pending import from Share Extension
    @State private var pendingImportURL: String? = nil

    /// Controls presentation of the import sheet
    @State private var showImportSheet: Bool = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if onboarding {
                    OnboardingView(pendingImportURL: $pendingImportURL)
                } else {
                    MainView(
                        pendingImportURL: $pendingImportURL,
                        showImportSheet: $showImportSheet
                    )
                }
            }
            .transition(.slide)
            .environment(
                \.locale,
                .init(identifier: language ==
                      SupportedLanguage.DEVICE.rawValue ? (Locale.current.language.languageCode?.identifier ?? "en") : language)
            )
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            .onAppear {
                checkForPendingImport()
            }
            .onChange(of: onboarding) { newValue in
                // When onboarding completes, check for pending import
                if !newValue {
                    checkForPendingImport()
                }
            }
        }
    }

    // MARK: - URL Handling

    /// Handles incoming URLs from the Share Extension
    private func handleIncomingURL(_ url: URL) {
        print("[App] Received URL: \(url)")
        guard url.scheme == "cookbook" else { 
            print("[App] URL scheme mismatch, ignoring")
            return 
        }

        // Extract the recipe URL from query parameter
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let importURLString = queryItems.first(where: { $0.name == "url" })?.value {
            print("[App] Found import URL in query: \(importURLString)")
            showImportSheet(for: importURLString)
        } else {
            // Fallback: check App Group storage
            print("[App] No URL in query, checking App Group...")
            checkForPendingImport()
        }
    }

    /// Shows the import sheet for the given URL
    private func showImportSheet(for urlString: String) {
        pendingImportURL = urlString
        
        if !onboarding {
            print("[App] Showing import sheet...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showImportSheet = true
            }
        } else {
            print("[App] Still onboarding, will show import after completion")
        }
    }

    /// Checks App Group storage for a pending URL to import (fallback)
    private func checkForPendingImport() {
        let pendingURL = SharedURLManager.shared.getPendingImportURL()
        print("[App] Pending URL from App Group: \(pendingURL ?? "nil")")
        
        guard let url = pendingURL, !url.isEmpty else {
            print("[App] No pending URL found")
            return
        }

        SharedURLManager.shared.clearPendingImportURL()
        showImportSheet(for: url)
    }
}
