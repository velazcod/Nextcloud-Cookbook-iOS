//
//  JsonLdDetector.swift
//  Nextcloud Cookbook iOS Client
//
//  Primary detection strategy for extracting recipe data from JSON-LD scripts
//

import Foundation
import SwiftSoup

/// JSON-LD detector - the primary detection method for structured recipe data
/// Handles standard JSON-LD scripts, @graph arrays, and malformed JSON recovery
class JsonLdDetector: RecipeDetector {
    var name: String { "JSON-LD" }
    
    func detect(in document: Document) -> RawRecipeData? {
        guard let scripts = try? document.select("script[type=application/ld+json]") else {
            return nil
        }
        
        for script in scripts.array() {
            guard let jsonString = try? script.html() else { continue }
            
            // Try standard parsing first
            if let data = parseJson(jsonString),
               let recipe = findRecipe(in: data) {
                return extractRawData(from: recipe)
            }
            
            // Try sanitized parsing for malformed JSON
            let sanitized = HtmlUtilities.sanitizeJsonString(jsonString)
            if let data = parseJson(sanitized),
               let recipe = findRecipe(in: data) {
                return extractRawData(from: recipe)
            }
        }
        
        return nil
    }
    
    // MARK: - JSON Parsing
    
    private func parseJson(_ string: String) -> Any? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }
    
    // MARK: - Recipe Discovery
    
    private func findRecipe(in data: Any) -> [String: Any]? {
        // Handle direct recipe object
        if let dict = data as? [String: Any], isRecipeType(dict) {
            return dict
        }
        
        // Handle array of objects
        if let array = data as? [Any] {
            for item in array {
                if let dict = item as? [String: Any], isRecipeType(dict) {
                    return dict
                }
            }
        }
        
        // Handle @graph array (common in structured data)
        if let dict = data as? [String: Any],
           let graph = dict["@graph"] as? [Any] {
            for item in graph {
                if let recipeDict = item as? [String: Any], isRecipeType(recipeDict) {
                    return recipeDict
                }
            }
        }
        
        return nil
    }
    
    private func isRecipeType(_ dict: [String: Any]) -> Bool {
        guard let type = dict["@type"] else { return false }
        
        // Handle string type
        if let typeString = type as? String {
            return isRecipeTypeString(typeString)
        }
        
        // Handle array of types
        if let typeArray = type as? [String] {
            return typeArray.contains { isRecipeTypeString($0) }
        }
        
        return false
    }
    
    private func isRecipeTypeString(_ type: String) -> Bool {
        let normalizedType = type.lowercased()
        return normalizedType == "recipe" ||
               normalizedType == "https://schema.org/recipe" ||
               normalizedType == "http://schema.org/recipe"
    }
    
    // MARK: - Data Extraction
    
    private func extractRawData(from dict: [String: Any]) -> RawRecipeData {
        var raw = RawRecipeData()
        
        // Core fields
        raw.name = dict["name"]
        raw.description = dict["description"]
        raw.url = dict["url"]
        
        // Image - can be string, array, or ImageObject
        raw.image = dict["image"]
        
        // Time fields
        raw.prepTime = dict["prepTime"]
        raw.cookTime = dict["cookTime"]
        raw.totalTime = dict["totalTime"]
        
        // Yield - handle aliases
        raw.recipeYield = dict["recipeYield"] ?? dict["yield"] ?? dict["servings"]
        
        // Ingredients - handle aliases
        raw.recipeIngredient = dict["recipeIngredient"] ?? dict["ingredients"] ?? dict["ingredient"]
        
        // Instructions - handle aliases
        raw.recipeInstructions = dict["recipeInstructions"] ?? dict["instructions"]
        
        // Category and cuisine - handle aliases
        raw.recipeCategory = dict["recipeCategory"] ?? dict["category"]
        raw.recipeCuisine = dict["recipeCuisine"] ?? dict["cuisine"]
        
        // Keywords
        raw.keywords = dict["keywords"]
        
        // Nutrition information
        raw.nutrition = dict["nutrition"]
        
        // Author
        raw.author = dict["author"]
        
        // Dates
        raw.dateCreated = dict["dateCreated"] ?? dict["datePublished"]
        raw.dateModified = dict["dateModified"]
        
        // Tools/Equipment
        raw.tool = dict["tool"]
        
        return raw
    }
}
