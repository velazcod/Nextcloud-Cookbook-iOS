//
//  ShareViewController.swift
//  Cookbook Share Extension
//
//  Handles incoming share requests and redirects to main app for recipe import.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    // MARK: - Constants
    
    private let appGroupId = "group.VincentMeilinger.Nextcloud-Cookbook-iOS-Client"
    private let sharedURLKey = "SharedImportURL"
    private let appURLScheme = "cookbook://import"
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        handleSharedContent()
    }
    
    // MARK: - Share Handling
    
    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            cancelRequest()
            return
        }
        
        guard let urlProvider = attachments.first(where: { 
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) 
        }) else {
            cancelRequest()
            return
        }
        
        urlProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading URL: \(error.localizedDescription)")
                self.cancelRequest()
                return
            }
            
            guard let url = item as? URL else {
                self.cancelRequest()
                return
            }
            
            self.saveURLAndOpenApp(url: url)
        }
    }
    
    private func saveURLAndOpenApp(url: URL) {
        guard let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let appURL = URL(string: "\(appURLScheme)?url=\(encodedURL)") else {
            completeRequest()
            return
        }
        
        if Thread.isMainThread {
            openContainingApp(appURL)
            completeRequest()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.openContainingApp(appURL)
                self?.completeRequest()
            }
        }
    }
    
    @discardableResult
    private func openContainingApp(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return true
            }
            responder = responder?.next
        }
        return false
    }
    
    // MARK: - Request Completion
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    private func cancelRequest() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "CookbookShareExtension",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not process shared content"]
        ))
    }
}
