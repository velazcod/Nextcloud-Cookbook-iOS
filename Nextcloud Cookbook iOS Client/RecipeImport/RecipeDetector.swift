//
//  RecipeDetector.swift
//  Nextcloud Cookbook iOS Client
//

import Foundation
import SwiftSoup

/// Protocol defining the interface for all recipe detection strategies
protocol RecipeDetector {
    /// Attempt to detect and extract a recipe from the parsed HTML document
    /// - Parameter document: SwiftSoup Document
    /// - Returns: Extracted recipe data or nil if detection fails
    func detect(in document: Document) -> RawRecipeData?
    
    /// Human-readable name for logging/debugging
    var name: String { get }
}

/// Struct to hold raw extracted data before normalization
/// All fields are Any? to handle various data formats from different sources
struct RawRecipeData {
    var name: Any?
    var description: Any?
    var image: Any?
    var prepTime: Any?
    var cookTime: Any?
    var totalTime: Any?
    var recipeYield: Any?
    var recipeIngredient: Any?
    var recipeInstructions: Any?
    var recipeCategory: Any?
    var recipeCuisine: Any?
    var keywords: Any?
    var nutrition: Any?
    var author: Any?
    var url: Any?
    var dateCreated: Any?
    var dateModified: Any?
    var tool: Any?
    
    init() {
        // All fields default to nil
    }
}