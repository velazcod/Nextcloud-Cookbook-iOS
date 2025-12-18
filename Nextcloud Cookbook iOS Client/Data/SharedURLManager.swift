//
//  SharedURLManager.swift
//  Nextcloud Cookbook iOS Client
//
//  Manages URL sharing between the Share Extension and main app via App Groups.
//

import Foundation

/// Manages shared URLs from the Share Extension using App Groups
class SharedURLManager {
    
    // MARK: - Singleton
    
    static let shared = SharedURLManager()
    
    // MARK: - Constants
    
    private let appGroupId = "group.VincentMeilinger.Nextcloud-Cookbook-iOS-Client"
    private let sharedURLKey = "SharedImportURL"
    
    // MARK: - Private Properties
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
    
    // MARK: - Initializer
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Retrieves the pending import URL from the Share Extension, if any
    func getPendingImportURL() -> String? {
        return sharedDefaults?.string(forKey: sharedURLKey)
    }
    
    /// Checks if there's a pending import URL
    func hasPendingImport() -> Bool {
        guard let url = getPendingImportURL() else { return false }
        return !url.isEmpty
    }
    
    /// Clears the pending import URL after it has been handled
    func clearPendingImportURL() {
        sharedDefaults?.removeObject(forKey: sharedURLKey)
        sharedDefaults?.synchronize()
    }
    
    /// Saves a URL for later import (used when user needs to complete onboarding first)
    func savePendingImportURL(_ url: String) {
        sharedDefaults?.set(url, forKey: sharedURLKey)
        sharedDefaults?.synchronize()
    }
}