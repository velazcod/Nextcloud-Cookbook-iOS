//
//  RecipeImportResult.swift
//  Nextcloud Cookbook iOS Client
//

import Foundation

// Forward declaration for RecipeDetail type from RecipeModels

struct RecipeImportResult {
    let recipe: RecipeDetail
    let warnings: [RecipeImportWarning]
    let detectionMethod: DetectionMethod
}

enum DetectionMethod: String {
    case jsonLd = "JSON-LD"
    case nextJs = "Next.js"
    case microdata = "Microdata"
}

enum RecipeImportWarning: Equatable {
    case missingIngredients
    case missingInstructions
    case missingImage
    case missingDescription
    case missingTimes
    
    var localizedDescription: String {
        switch self {
        case .missingIngredients:
            return String(localized: "No ingredients found")
        case .missingInstructions:
            return String(localized: "No instructions found")
        case .missingImage:
            return String(localized: "No image found")
        case .missingDescription:
            return String(localized: "No description found")
        case .missingTimes:
            return String(localized: "No cooking times found")
        }
    }
}