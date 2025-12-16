//
//  RecipeScraper.swift
//  Nextcloud Cookbook iOS Client
//
//  Created by Vincent Meilinger on 09.11.23.
//

import Foundation
import SwiftSoup
import OSLog

class RecipeScraper {
    private let logger = Logger.recipeImport
    
    /// Detection strategies in priority order
    private let detectors: [RecipeDetector] = [
        JsonLdDetector(),
        NextJsDetector(),
        MicrodataDetector()
    ]
    
    /// Scrape a recipe from the given URL
    /// - Parameter url: The URL to scrape
    /// - Returns: A tuple containing the import result (or nil) and any error alert
    func scrape(url: String) async throws -> (RecipeImportResult?, RecipeImportAlert?) {
        // Validate URL
        guard let validUrl = URL(string: url), validUrl.scheme != nil else {
            logger.error("Invalid URL: \(url)")
            return (nil, .BAD_URL)
        }
        
        // Fetch HTML content
        let html: String
        do {
            html = try await fetchHtml(from: validUrl)
        } catch {
            logger.error("Failed to fetch URL: \(error.localizedDescription)")
            return (nil, .CHECK_CONNECTION)
        }
        
        // Parse HTML with SwiftSoup
        let document: Document
        do {
            document = try SwiftSoup.parse(html)
        } catch {
            logger.error("Failed to parse HTML: \(error.localizedDescription)")
            return (nil, .PARSE_ERROR)
        }
        
        // Try each detector in order
        for detector in detectors {
            logger.debug("Trying detector: \(detector.name)")
            
            if let rawData = detector.detect(in: document) {
                logger.info("Recipe detected using \(detector.name)")
                
                // Normalize raw data to RecipeDetail
                let result = normalize(rawData: rawData, sourceUrl: url, detectionMethod: detector.detectionMethod)
                
                // Check if we got a valid recipe (at least a name)
                if result.recipe.name.isEmpty {
                    logger.warning("Detected recipe has no name, trying next detector")
                    continue
                }
                
                // Return result with any warnings
                if result.warnings.isEmpty {
                    return (result, nil)
                } else {
                    return (result, .PARTIAL_IMPORT(warnings: result.warnings))
                }
            }
        }
        
        // No detector succeeded
        logger.warning("No recipe found at URL: \(url)")
        return (nil, .NO_RECIPE_FOUND)
    }
    
    /// Fetch HTML content from URL
    private func fetchHtml(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return html
    }
    
    /// Normalize raw recipe data into a RecipeDetail object
    private func normalize(rawData: RawRecipeData, sourceUrl: String, detectionMethod: DetectionMethod) -> RecipeImportResult {
        var warnings: [RecipeImportWarning] = []
        
        // Extract and normalize all fields using RecipeFieldExtractor
        let name = RecipeFieldExtractor.extractString(rawData.name) ?? "New Recipe"
        let description = RecipeFieldExtractor.extractString(rawData.description) ?? ""
        let imageUrl = RecipeFieldExtractor.extractImage(rawData.image)
        let prepTime = RecipeFieldExtractor.extractString(rawData.prepTime)
        let cookTime = RecipeFieldExtractor.extractString(rawData.cookTime)
        let totalTime = RecipeFieldExtractor.extractString(rawData.totalTime)
        let (yieldNumeric, yieldText) = RecipeFieldExtractor.extractYield(rawData.recipeYield)
        let ingredients = RecipeFieldExtractor.extractIngredients(rawData.recipeIngredient)
        let instructions = RecipeFieldExtractor.extractInstructions(rawData.recipeInstructions)
        let keywords = RecipeFieldExtractor.extractKeywords(rawData.keywords)
        let category = RecipeFieldExtractor.extractString(rawData.recipeCategory) ?? ""
        let nutrition = RecipeFieldExtractor.extractNutrition(rawData.nutrition)
        let tools = extractTools(rawData.tool)
        
        // Generate warnings for missing important fields
        if ingredients.isEmpty {
            warnings.append(.missingIngredients)
        }
        if instructions.isEmpty {
            warnings.append(.missingInstructions)
        }
        if imageUrl == nil || imageUrl?.isEmpty == true {
            warnings.append(.missingImage)
        }
        if description.isEmpty {
            warnings.append(.missingDescription)
        }
        if prepTime == nil && cookTime == nil && totalTime == nil {
            warnings.append(.missingTimes)
        }
        
        // Create RecipeDetail
        let recipe = RecipeDetail(
            name: name,
            keywords: keywords.joined(separator: ","),
            dateCreated: ISO8601DateFormatter().string(from: Date()),
            dateModified: ISO8601DateFormatter().string(from: Date()),
            imageUrl: imageUrl ?? "",
            id: "",  // Will be assigned by server on save
            prepTime: prepTime,
            cookTime: cookTime,
            totalTime: totalTime,
            description: description,
            url: sourceUrl,
            recipeYield: yieldNumeric,
            recipeYieldText: yieldText,
            recipeCategory: category,
            tool: tools,
            recipeIngredient: ingredients,
            recipeInstructions: instructions,
            nutrition: nutrition
        )
        
        return RecipeImportResult(
            recipe: recipe,
            warnings: warnings,
            detectionMethod: detectionMethod
        )
    }
    
    /// Extract tools from various formats
    private func extractTools(_ value: Any?) -> [String] {
        guard let value = value else { return [] }
        
        // Handle array of strings directly
        if let arrayValue = value as? [String] {
            return arrayValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        
        // Handle array of dictionaries with name/text
        if let arrayValue = value as? [[String: Any]] {
            return arrayValue.compactMap { dict in
                if let name = dict["name"] as? String {
                    return name.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let text = dict["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return nil
            }
        }
        
        // Handle single string
        if let stringValue = value as? String {
            return [stringValue.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        
        return []
    }
}

// MARK: - RecipeDetector Protocol Extension

extension RecipeDetector {
    var detectionMethod: DetectionMethod {
        switch name {
        case "JSON-LD": return .jsonLd
        case "Next.js": return .nextJs
        case "Microdata": return .microdata
        default: return .jsonLd
        }
    }
}
