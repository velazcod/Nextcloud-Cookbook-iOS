//
//  NextJsDetector.swift
//  Nextcloud Cookbook iOS Client
//
//  Secondary detection strategy for extracting recipe data from Next.js __NEXT_DATA__ scripts
//

import Foundation
import SwiftSoup

/// Next.js detector - handles modern React-based recipe sites with __NEXT_DATA__ hydration
class NextJsDetector: RecipeDetector {
    var name: String { "Next.js" }
    
    // Common paths where recipe data is stored in Next.js apps
    private let recipePaths: [[String]] = [
        ["props", "pageProps", "recipe"],
        ["props", "pageProps", "data", "recipe"],
        ["props", "pageProps", "initialData", "recipe"],
        ["props", "pageProps", "post", "recipe"],
        ["props", "pageProps", "recipeData"],
        ["props", "pageProps", "data"],
        ["props", "pageProps"]
    ]
    
    func detect(in document: Document) -> RawRecipeData? {
        guard let script = try? document.select("script#__NEXT_DATA__").first(),
              let jsonString = try? script.html(),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Search common paths for recipe data
        for path in recipePaths {
            if let recipe = getValueAtPath(json, path: path) as? [String: Any] {
                // Verify this looks like recipe data (has name or title)
                if recipe["name"] != nil || recipe["title"] != nil {
                    return convertToRawData(recipe)
                }
            }
        }
        
        // Deep search for recipe data if common paths fail
        if let recipe = deepSearchForRecipe(in: json) {
            return convertToRawData(recipe)
        }
        
        return nil
    }
    
    // MARK: - Path Navigation
    
    private func getValueAtPath(_ dict: [String: Any], path: [String]) -> Any? {
        var current: Any = dict
        for key in path {
            guard let currentDict = current as? [String: Any],
                  let next = currentDict[key] else {
                return nil
            }
            current = next
        }
        return current
    }
    
    private func deepSearchForRecipe(in data: Any) -> [String: Any]? {
        if let dict = data as? [String: Any] {
            // Check if this dict looks like a recipe
            if hasRecipeIndicators(dict) {
                return dict
            }
            
            // Search nested values
            for (_, value) in dict {
                if let found = deepSearchForRecipe(in: value) {
                    return found
                }
            }
        }
        
        if let array = data as? [Any] {
            for item in array {
                if let found = deepSearchForRecipe(in: item) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    private func hasRecipeIndicators(_ dict: [String: Any]) -> Bool {
        // Must have name or title
        guard dict["name"] != nil || dict["title"] != nil else {
            return false
        }
        
        // Must have at least one of these recipe-specific fields
        let recipeFields = ["recipeIngredient", "ingredients", "recipeInstructions", 
                           "instructions", "prepTime", "cookTime", "recipeYield",
                           "recipeDetails", "recipeParts"]
        
        return recipeFields.contains { dict[$0] != nil }
    }
    
    // MARK: - Data Conversion
    
    private func convertToRawData(_ recipe: [String: Any]) -> RawRecipeData {
        var raw = RawRecipeData()
        
        // Name/Title
        raw.name = recipe["name"] ?? recipe["title"]
        
        // Description - handle block-based formats (Sanity CMS style)
        raw.description = extractNextJsDescription(recipe["description"])
        
        // Image - handle Sanity CDN and other formats
        raw.image = extractNextJsImage(recipe["image"] ?? recipe["featuredImage"])
        
        // URL
        raw.url = recipe["url"] ?? recipe["canonicalUrl"]
        
        // Time fields - may need human-readable to ISO conversion
        let recipeDetails = recipe["recipeDetails"] as? [String: Any]
        raw.prepTime = convertTimeToISO8601(recipe["prepTime"] ?? recipeDetails?["prepTime"])
        raw.cookTime = convertTimeToISO8601(recipe["cookTime"] ?? recipeDetails?["cookTime"])
        raw.totalTime = convertTimeToISO8601(recipe["totalTime"] ?? recipeDetails?["totalTime"])
        
        // Yield
        raw.recipeYield = recipe["recipeYield"] ?? recipeDetails?["recipeYield"] ?? recipe["servings"] ?? recipeDetails?["servings"]
        
        // Ingredients - handle nested structures
        raw.recipeIngredient = extractNextJsIngredients(recipe)
        
        // Instructions - handle nested structures
        raw.recipeInstructions = extractNextJsInstructions(recipe)
        
        // Author
        raw.author = recipe["author"] ?? recipe["authorName"]
        
        // Keywords/Tags
        raw.keywords = recipe["keywords"] ?? recipe["tags"]
        
        // Category and Cuisine
        raw.recipeCategory = recipe["recipeCategory"] ?? recipe["category"]
        raw.recipeCuisine = recipe["recipeCuisine"] ?? recipe["cuisine"]
        
        // Nutrition
        raw.nutrition = recipe["nutrition"]
        
        // Dates
        raw.dateCreated = recipe["dateCreated"] ?? recipe["datePublished"] ?? recipe["publishedAt"]
        raw.dateModified = recipe["dateModified"] ?? recipe["updatedAt"]
        
        return raw
    }
    
    // MARK: - Time Conversion
    
    private func convertTimeToISO8601(_ value: Any?) -> Any? {
        guard let timeString = value as? String else { return value }
        
        // If already ISO 8601 format (PT...), return as-is
        if timeString.hasPrefix("P") { return timeString }
        
        // Convert human-readable format: "45 Minutes" -> "PT45M", "1 hour 30 minutes" -> "PT1H30M"
        var hours = 0
        var minutes = 0
        
        let hourPattern = try? NSRegularExpression(pattern: "(\\d+)\\s*hours?", options: .caseInsensitive)
        let minPattern = try? NSRegularExpression(pattern: "(\\d+)\\s*(?:minutes?|mins?)", options: .caseInsensitive)
        
        let nsString = timeString as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        if let match = hourPattern?.firstMatch(in: timeString, options: [], range: range),
           let hourRange = Range(match.range(at: 1), in: timeString) {
            hours = Int(timeString[hourRange]) ?? 0
        }
        
        if let match = minPattern?.firstMatch(in: timeString, options: [], range: range),
           let minRange = Range(match.range(at: 1), in: timeString) {
            minutes = Int(timeString[minRange]) ?? 0
        }
        
        if hours == 0 && minutes == 0 { return timeString }
        
        var iso = "PT"
        if hours > 0 { iso += "\(hours)H" }
        if minutes > 0 { iso += "\(minutes)M" }
        return iso
    }
    
    // MARK: - Description Extraction
    
    private func extractNextJsDescription(_ value: Any?) -> Any? {
        guard let value = value else { return nil }
        
        // Handle string directly
        if let stringValue = value as? String {
            return stringValue
        }
        
        // Handle block-based descriptions (Sanity CMS style)
        // Format: [{ "children": [{ "text": "Description paragraph" }] }]
        if let blocks = value as? [[String: Any]] {
            var texts: [String] = []
            for block in blocks {
                if let children = block["children"] as? [[String: Any]] {
                    for child in children {
                        if let text = child["text"] as? String, !text.isEmpty {
                            texts.append(text)
                        }
                    }
                }
            }
            if !texts.isEmpty {
                return texts.joined(separator: "\n\n")
            }
        }
        
        return value
    }
    
    // MARK: - Image Extraction
    
    private func extractNextJsImage(_ value: Any?) -> Any? {
        guard let value = value else { return nil }
        
        // Handle string directly (URL)
        if let stringValue = value as? String {
            return stringValue
        }
        
        // Handle array - get first image
        if let arrayValue = value as? [Any], let first = arrayValue.first {
            return extractNextJsImage(first)
        }
        
        // Handle object with url
        if let dictValue = value as? [String: Any] {
            // Standard url key
            if let url = dictValue["url"] as? String {
                return url
            }
            
            // Sanity CDN image format
            // { "asset": { "url": "https://cdn.sanity.io/..." } }
            if let asset = dictValue["asset"] as? [String: Any],
               let url = asset["url"] as? String {
                return url
            }
            
            // src key
            if let src = dictValue["src"] as? String {
                return src
            }
        }
        
        return value
    }
    
    // MARK: - Ingredients Extraction
    
    private func extractNextJsIngredients(_ recipe: [String: Any]) -> Any? {
        // Try standard keys
        if let ingredients = recipe["recipeIngredient"] ?? recipe["ingredients"] {
            // Handle array of strings directly
            if let array = ingredients as? [String] {
                return array
            }
            
            // Handle array of objects with text
            if let array = ingredients as? [[String: Any]] {
                return array.compactMap { $0["text"] as? String ?? $0["ingredient"] as? String }
            }
            
            return ingredients
        }
        
        // Handle nested recipeParts format (Food52 style)
        // { "recipeDetails": { "recipeParts": [{ "recipePartIngredients": { "ingredients": [...] } }] } }
        if let recipeDetails = recipe["recipeDetails"] as? [String: Any],
           let recipeParts = recipeDetails["recipeParts"] as? [[String: Any]] {
            var allIngredients: [String] = []
            
            for part in recipeParts {
                if let ingredientSection = part["recipePartIngredients"] as? [String: Any],
                   let ingredients = ingredientSection["ingredients"] as? [[String: Any]] {
                    for ingredient in ingredients {
                        if let formatted = formatIngredient(ingredient) {
                            allIngredients.append(formatted)
                        }
                    }
                }
            }
            
            if !allIngredients.isEmpty {
                return allIngredients
            }
        }
        
        return nil
    }
    
    private func formatIngredient(_ ingredient: [String: Any]) -> String? {
        // Format: { "ingredientAmount": "2", "ingredientUnit": "cups", "ingredientName": "flour" }
        let amount = ingredient["ingredientAmount"] as? String ?? ingredient["amount"] as? String ?? ""
        let unit = ingredient["ingredientUnit"] as? String ?? ingredient["unit"] as? String ?? ""
        let name = ingredient["ingredientName"] as? String ?? ingredient["name"] as? String ?? ""
        
        if name.isEmpty { return nil }
        
        var parts: [String] = []
        if !amount.isEmpty { parts.append(amount) }
        if !unit.isEmpty { parts.append(unit) }
        parts.append(name)
        
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Instructions Extraction
    
    private func extractNextJsInstructions(_ recipe: [String: Any]) -> Any? {
        // Try standard keys
        if let instructions = recipe["recipeInstructions"] ?? recipe["instructions"] {
            // Handle array of strings directly
            if let array = instructions as? [String] {
                return array
            }
            
            // Handle array of HowToStep objects
            if let array = instructions as? [[String: Any]] {
                return array.compactMap { step -> String? in
                    if let text = step["text"] as? String { return text }
                    if let name = step["name"] as? String { return name }
                    return nil
                }
            }
            
            return instructions
        }
        
        // Handle nested recipeParts format with block-based directions
        // { "recipeDetails": { "recipeParts": [{ "recipePartDirections": [{ "children": [{ "text": "..." }] }] }] } }
        if let recipeDetails = recipe["recipeDetails"] as? [String: Any],
           let recipeParts = recipeDetails["recipeParts"] as? [[String: Any]] {
            var allInstructions: [String] = []
            
            for part in recipeParts {
                if let directions = part["recipePartDirections"] as? [[String: Any]] {
                    for direction in directions {
                        if let children = direction["children"] as? [[String: Any]] {
                            for child in children {
                                if let text = child["text"] as? String, !text.isEmpty {
                                    allInstructions.append(text)
                                }
                            }
                        } else if let text = direction["text"] as? String, !text.isEmpty {
                            allInstructions.append(text)
                        }
                    }
                }
            }
            
            if !allInstructions.isEmpty {
                return allInstructions
            }
        }
        
        return nil
    }
}
