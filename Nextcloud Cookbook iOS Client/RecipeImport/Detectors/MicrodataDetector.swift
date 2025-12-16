//
//  MicrodataDetector.swift
//  Nextcloud Cookbook iOS Client
//
//  Tertiary detection strategy for extracting recipe data from HTML5 microdata attributes
//

import Foundation
import SwiftSoup

/// Microdata detector - handles older sites using HTML5 microdata attributes
/// Extracts data from itemtype and itemprop attributes per schema.org specification
class MicrodataDetector: RecipeDetector {
    var name: String { "Microdata" }
    
    func detect(in document: Document) -> RawRecipeData? {
        // Find the recipe element with itemtype containing schema.org/Recipe
        guard let recipeElement = try? document.select("[itemtype*='schema.org/Recipe']").first() else {
            return nil
        }
        
        var raw = RawRecipeData()
        
        // Extract each property
        raw.name = extractProperty(recipeElement, "name")
        raw.description = extractProperty(recipeElement, "description")
        raw.image = extractImageProperty(recipeElement)
        raw.prepTime = extractProperty(recipeElement, "prepTime")
        raw.cookTime = extractProperty(recipeElement, "cookTime")
        raw.totalTime = extractProperty(recipeElement, "totalTime")
        raw.recipeYield = extractProperty(recipeElement, "recipeYield")
        raw.recipeCategory = extractProperty(recipeElement, "recipeCategory")
        raw.recipeCuisine = extractProperty(recipeElement, "recipeCuisine")
        raw.keywords = extractProperty(recipeElement, "keywords")
        raw.author = extractAuthorProperty(recipeElement)
        raw.recipeIngredient = extractMultipleProperties(recipeElement, "recipeIngredient")
        raw.recipeInstructions = extractInstructionProperties(recipeElement)
        raw.nutrition = extractNutritionProperties(recipeElement)
        raw.url = extractProperty(recipeElement, "url")
        raw.dateCreated = extractProperty(recipeElement, "datePublished") ?? extractProperty(recipeElement, "dateCreated")
        raw.dateModified = extractProperty(recipeElement, "dateModified")
        
        // Validate we found at least a name
        guard raw.name != nil else { return nil }
        
        return raw
    }
    
    // MARK: - Single Property Extraction
    
    private func extractProperty(_ element: Element, _ property: String) -> String? {
        guard let propElement = try? element.select("[itemprop=\(property)]").first() else {
            return nil
        }
        return extractValueFromElement(propElement)
    }
    
    private func extractValueFromElement(_ element: Element) -> String? {
        let tagName = element.tagName().lowercased()
        
        switch tagName {
        case "meta":
            if let content = try? element.attr("content"), !content.isEmpty {
                return content
            }
        case "img":
            if let src = try? element.attr("src"), !src.isEmpty {
                return src
            }
        case "a", "link":
            if let href = try? element.attr("href"), !href.isEmpty {
                return href
            }
        case "time":
            // Try datetime attribute first (ISO 8601 format)
            if let datetime = try? element.attr("datetime"), !datetime.isEmpty {
                return datetime
            }
            // Fall back to text content
            if let text = try? element.text(), !text.isEmpty {
                return text
            }
        case "data":
            // data elements store values in value attribute
            if let value = try? element.attr("value"), !value.isEmpty {
                return value
            }
        default:
            // Check for content attribute first (common for meta-like usage)
            if let content = try? element.attr("content"), !content.isEmpty {
                return content
            }
            // Fall back to text content
            if let text = try? element.text(), !text.isEmpty {
                return text
            }
        }
        
        return nil
    }
    
    // MARK: - Image Property
    
    private func extractImageProperty(_ element: Element) -> String? {
        // Try various image property selectors
        let selectors = [
            "[itemprop=image]",
            "[itemprop=thumbnailUrl]"
        ]
        
        for selector in selectors {
            guard let imgElement = try? element.select(selector).first() else { continue }
            
            let tagName = imgElement.tagName().lowercased()
            
            if tagName == "img" {
                if let src = try? imgElement.attr("src"), !src.isEmpty {
                    return src
                }
            } else if tagName == "meta" || tagName == "link" {
                if let content = try? imgElement.attr("content"), !content.isEmpty {
                    return content
                }
                if let href = try? imgElement.attr("href"), !href.isEmpty {
                    return href
                }
            } else {
                // Check for nested img
                if let nestedImg = try? imgElement.select("img").first(),
                   let src = try? nestedImg.attr("src"), !src.isEmpty {
                    return src
                }
                // Check for content attribute
                if let content = try? imgElement.attr("content"), !content.isEmpty {
                    return content
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Multiple Properties
    
    private func extractMultipleProperties(_ element: Element, _ property: String) -> [String] {
        guard let elements = try? element.select("[itemprop=\(property)]") else {
            return []
        }
        return elements.array().compactMap { extractValueFromElement($0) }
    }
    
    // MARK: - Instruction Extraction
    
    private func extractInstructionProperties(_ element: Element) -> [Any] {
        // Try HowToStep elements first (structured instructions)
        if let steps = try? element.select("[itemtype*='HowToStep']"), !steps.isEmpty() {
            return extractHowToSteps(steps)
        }
        
        // Try HowToSection with nested steps
        if let sections = try? element.select("[itemtype*='HowToSection']"), !sections.isEmpty() {
            var allSteps: [String] = []
            for section in sections.array() {
                if let sectionSteps = try? section.select("[itemtype*='HowToStep']") {
                    allSteps.append(contentsOf: extractHowToSteps(sectionSteps))
                }
            }
            if !allSteps.isEmpty {
                return allSteps
            }
        }
        
        // Fall back to recipeInstructions property
        let instructions = extractMultipleProperties(element, "recipeInstructions")
        if !instructions.isEmpty {
            return instructions
        }
        
        // Try instructions property as alternative
        return extractMultipleProperties(element, "instructions")
    }
    
    private func extractHowToSteps(_ steps: Elements) -> [String] {
        return steps.array().compactMap { step -> String? in
            // Try text property first
            if let textElement = try? step.select("[itemprop=text]").first() {
                return extractValueFromElement(textElement)
            }
            
            // Try name property
            if let nameElement = try? step.select("[itemprop=name]").first() {
                return extractValueFromElement(nameElement)
            }
            
            // Try description property
            if let descElement = try? step.select("[itemprop=description]").first() {
                return extractValueFromElement(descElement)
            }
            
            // Fall back to the step's text content
            return try? step.text()
        }
    }
    
    // MARK: - Author Extraction
    
    private func extractAuthorProperty(_ element: Element) -> String? {
        guard let authorElement = try? element.select("[itemprop=author]").first() else {
            return nil
        }
        
        // Check if author has nested name property (Person or Organization)
        if let nameElement = try? authorElement.select("[itemprop=name]").first() {
            return extractValueFromElement(nameElement)
        }
        
        // Fall back to the author element's value
        return extractValueFromElement(authorElement)
    }
    
    // MARK: - Nutrition Extraction
    
    private func extractNutritionProperties(_ element: Element) -> [String: String]? {
        // Find NutritionInformation itemtype
        guard let nutritionElement = try? element.select("[itemtype*='NutritionInformation']").first() else {
            // Also try without itemtype, just itemprop="nutrition"
            guard let nutritionProp = try? element.select("[itemprop=nutrition]").first() else {
                return nil
            }
            return extractNutritionFromElement(nutritionProp)
        }
        
        return extractNutritionFromElement(nutritionElement)
    }
    
    private func extractNutritionFromElement(_ element: Element) -> [String: String]? {
        var nutrition: [String: String] = [:]
        
        // Standard nutrition property names from schema.org
        let nutritionProps = [
            "calories",
            "fatContent",
            "saturatedFatContent",
            "unsaturatedFatContent",
            "transFatContent",
            "carbohydrateContent",
            "sugarContent",
            "fiberContent",
            "proteinContent",
            "sodiumContent",
            "cholesterolContent",
            "servingSize"
        ]
        
        for prop in nutritionProps {
            if let value = extractProperty(element, prop) {
                nutrition[prop] = value
            }
        }
        
        return nutrition.isEmpty ? nil : nutrition
    }
}
