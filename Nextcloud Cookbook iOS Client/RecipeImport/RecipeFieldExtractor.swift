//
//  RecipeFieldExtractor.swift
//  Nextcloud Cookbook iOS Client
//

import Foundation

struct RecipeFieldExtractor {
    /// Extract string value from various schema.org formats
    static func extractString(_ value: Any?) -> String? {
        guard let value = value else { return nil }
        
        // Handle String directly
        if let stringValue = value as? String {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Handle array of values
        if let arrayValue = value as? [Any], let first = arrayValue.first {
            return extractString(first)
        }
        
        // Handle dictionary formats
        if let dictValue = value as? [String: Any] {
            // Try common keys
            if let text = dictValue["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let name = dictValue["name"] as? String {
                return name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let value = dictValue["@value"] as? String {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let id = dictValue["@id"] as? String {
                return id.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    /// Extract image URL from various formats
    static func extractImage(_ value: Any?) -> String? {
        guard let value = value else { return nil }

        // Handle String directly (URL)
        if let stringValue = value as? String {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Handle array of values
        if let arrayValue = value as? [Any], let first = arrayValue.first {
            return extractImage(first)
        }

        // Handle dictionary formats
        if let dictValue = value as? [String: Any] {
            // Try common keys - use extractString to handle nested structures
            if let url = extractString(dictValue["url"]) {
                return url
            }
            if let contentUrl = extractString(dictValue["contentUrl"]) {
                return contentUrl
            }
            if let id = extractString(dictValue["@id"]) {
                return id
            }
            // Additional keys that might contain image URLs
            if let thumbnail = extractString(dictValue["thumbnail"]) {
                return thumbnail
            }
            if let src = extractString(dictValue["src"]) {
                return src
            }
            // Handle ImageObject with nested url
            if let imageObject = dictValue["image"] as? [String: Any],
               let nestedUrl = extractString(imageObject["url"]) {
                return nestedUrl
            }
        }

        return nil
    }
    
    /// Extract ingredients from various formats
    static func extractIngredients(_ value: Any?) -> [String] {
        guard let value = value else { return [] }
        
        // Handle array of strings directly
        if let arrayValue = value as? [String] {
            return arrayValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        
        // Handle array of dictionaries with text
        if let arrayValue = value as? [[String: Any]] {
            return arrayValue.compactMap { dict in
                if let text = dict["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return nil
            }
        }
        
        // Handle newline-separated string
        if let stringValue = value as? String {
            return stringValue
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        return []
    }
    
    /// Extract instructions from various formats
    static func extractInstructions(_ value: Any?) -> [String] {
        guard let value = value else { return [] }

        // Handle array of strings directly
        if let arrayValue = value as? [String] {
            return arrayValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        // Handle array of HowToSection dictionaries (common in schema.org)
        if let arrayValue = value as? [[String: Any]] {
            var allInstructions: [String] = []

            for section in arrayValue {
                // Check if this is a HowToSection with itemListElement
                if let steps = section["itemListElement"] as? [[String: Any]] {
                    let sectionInstructions = steps.compactMap { step -> String? in
                        if let text = step["text"] as? String {
                            return text.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if let name = step["name"] as? String {
                            return name.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        return nil
                    }
                    allInstructions.append(contentsOf: sectionInstructions)
                }
                // If no itemListElement, try to treat the section as a direct step
                else if let text = section["text"] as? String {
                    allInstructions.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
                } else if let name = section["name"] as? String {
                    allInstructions.append(name.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }

            if !allInstructions.isEmpty {
                return allInstructions
            }
        }

        // Handle HowToSection format (single section)
        if let dictValue = value as? [String: Any],
            let steps = dictValue["itemListElement"] as? [[String: Any]] {
            return steps.compactMap { step in
                if let text = step["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let name = step["name"] as? String {
                    return name.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return nil
            }
        }

        // Handle single string
        if let stringValue = value as? String {
            return stringValue
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return []
    }
    
    /// Extract keywords from various formats
    static func extractKeywords(_ value: Any?) -> [String] {
        guard let value = value else { return [] }
        
        // Handle array of strings directly
        if let arrayValue = value as? [String] {
            return arrayValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        
        // Handle comma-separated string
        if let stringValue = value as? String {
            return stringValue
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        return []
    }
    
    /// Extract author from various formats
    static func extractAuthor(_ value: Any?) -> String? {
        guard let value = value else { return nil }
        
        // Handle String directly
        if let stringValue = value as? String {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Handle array of values
        if let arrayValue = value as? [Any], let first = arrayValue.first {
            return extractAuthor(first)
        }
        
        // Handle dictionary format
        if let dictValue = value as? [String: Any] {
            if let name = dictValue["name"] as? String {
                return name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    /// Extract yield information
    static func extractYield(_ value: Any?) -> (numeric: Int, text: String?) {
        guard let value = value else { return (0, nil) }
        
        // Handle Int directly
        if let intValue = value as? Int {
            return (intValue, nil)
        }
        
        // Handle String
        if let stringValue = value as? String {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try to extract number from string like "4 servings"
            if let number = extractNumber(from: trimmed) {
                return (number, trimmed)
            }
            
            return (0, trimmed)
        }
        
        return (0, nil)
    }
    
    /// Extract nutrition information
    static func extractNutrition(_ value: Any?) -> [String: String] {
        guard let value = value else { return [:] }
        
        if let dictValue = value as? [String: Any] {
            return dictValue.compactMapValues { subValue in
                if let stringValue = subValue as? String {
                    return stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return nil
            }
        }
        
        return [:]
    }
    
    /// Helper to extract number from string
    private static func extractNumber(from string: String) -> Int? {
        let numberPattern = "\\d+"
        if let regex = try? NSRegularExpression(pattern: numberPattern),
           let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
           let range = Range(match.range, in: string) {
            return Int(string[range])
        }
        return nil
    }
}