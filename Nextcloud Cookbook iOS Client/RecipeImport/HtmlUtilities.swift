//
//  HtmlUtilities.swift
//  Nextcloud Cookbook iOS Client
//

import Foundation

struct HtmlUtilities {
    /// Decode HTML entities in a string
    static func decodeHtmlEntities(_ string: String) -> String {
        var result = string
        
        // Common named entities
        let namedEntities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
            "&hellip;": "…",
            "&mdash;": "—",
            "&ndash;": "–",
            "&lsquo;": "'",
            "&rsquo;": "'",
            "&ldquo;": "\"",
            "&rdquo;": "\"",
            "&bull;": "•",
            "&deg;": "°",
            "&frac12;": "½",
            "&frac14;": "¼",
            "&frac34;": "¾"
        ]
        
        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // For now, we'll skip complex entity decoding and rely on SwiftSoup for this
        // This is a placeholder for future enhancement
        
        return result
    }
    
    /// Strip HTML tags from a string using regex
    static func stripHtmlTags(_ string: String) -> String {
        let pattern = "<[^>]+>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return string
        }
        
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: "")
    }
    
    /// Sanitize JSON string by fixing unescaped characters
    static func sanitizeJsonString(_ jsonString: String) -> String {
        var result = jsonString
        
        // Replace unescaped newlines with \n
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r")
        result = result.replacingOccurrences(of: "\t", with: "\\t")
        
        // Fix double backslashes that might have been escaped
        result = result.replacingOccurrences(of: "\\\\", with: "\\")
        
        return result
    }
    
    /// Clean ingredient text
    static func cleanIngredient(_ ingredient: String) -> String {
        let withoutHtml = stripHtmlTags(ingredient)
        let decoded = decodeHtmlEntities(withoutHtml)
        return decoded
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    /// Clean instruction text
    static func cleanInstruction(_ instruction: String) -> String {
        let withoutHtml = stripHtmlTags(instruction)
        let decoded = decodeHtmlEntities(withoutHtml)
        
        var cleaned = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common step number prefixes
        let stepPatterns = [
            "^\\d+\\.\\s*",    // "1. "
            "^Step\\s*\\d+:\\s*", // "Step 1: "
            "^\\(\\d+\\)\\s*", // "(1) "
            "^•\\s*"          // "• "
        ]
        
        for pattern in stepPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: cleaned.utf16.count)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }
        
        return cleaned
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}