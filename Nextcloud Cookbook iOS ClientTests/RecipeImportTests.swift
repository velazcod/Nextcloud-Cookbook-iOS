//
//  RecipeImportTests.swift
//  Nextcloud Cookbook iOS ClientTests
//
//  Unit tests for the recipe import system
//

import XCTest
import SwiftSoup
@testable import Nextcloud_Cookbook_iOS_Client

final class RecipeImportTests: XCTestCase {
    
    // MARK: - JSON-LD Detection Tests
    
    func testStandardJsonLdParsing() throws {
        // Test standard schema.org Recipe JSON-LD
        let jsonLd = """
        {
            "@type": "Recipe",
            "name": "Chocolate Chip Cookies",
            "description": "Classic cookies",
            "recipeIngredient": ["2 cups flour", "1 cup sugar"],
            "recipeInstructions": [
                {"@type": "HowToStep", "text": "Mix ingredients"},
                {"@type": "HowToStep", "text": "Bake at 350F"}
            ]
        }
        """
        
        let document = try createDocumentWithJsonLd(jsonLd)
        let detector = JsonLdDetector()
        
        let result = detector.detect(in: document)
        
        XCTAssertNotNil(result, "Should detect recipe from standard JSON-LD")
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.name), "Chocolate Chip Cookies")
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.description), "Classic cookies")
    }
    
    func testJsonLdWithGraphArray() throws {
        // Test JSON-LD with @graph wrapper
        let jsonLd = """
        {
            "@context": "https://schema.org",
            "@graph": [
                {"@type": "WebPage", "name": "Recipe Page"},
                {"@type": "Recipe", "name": "Pasta Carbonara", "description": "Italian classic"}
            ]
        }
        """
        
        let document = try createDocumentWithJsonLd(jsonLd)
        let detector = JsonLdDetector()
        
        let result = detector.detect(in: document)
        
        XCTAssertNotNil(result, "Should extract Recipe from @graph array")
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.name), "Pasta Carbonara")
    }
    
    func testJsonLdWithSchemaOrgPrefix() throws {
        // Test type with full schema.org URL
        let jsonLd = """
        {
            "@type": "https://schema.org/Recipe",
            "name": "Test Recipe",
            "description": "A recipe with full schema URL"
        }
        """
        
        let document = try createDocumentWithJsonLd(jsonLd)
        let detector = JsonLdDetector()
        
        let result = detector.detect(in: document)
        
        XCTAssertNotNil(result, "Should recognize Recipe type with schema.org prefix")
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.name), "Test Recipe")
    }
    
    func testJsonLdWithArrayType() throws {
        // Test type as array
        let jsonLd = """
        {
            "@type": ["Recipe", "FoodRecipe"],
            "name": "Multi-type Recipe"
        }
        """
        
        let document = try createDocumentWithJsonLd(jsonLd)
        let detector = JsonLdDetector()
        
        let result = detector.detect(in: document)
        
        XCTAssertNotNil(result, "Should recognize Recipe in array type")
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.name), "Multi-type Recipe")
    }
    
    func testJsonLdWithArrayOfRecipes() throws {
        // Test array containing recipe objects (not @graph)
        let jsonLd = """
        [
            {"@type": "Organization", "name": "Test Org"},
            {"@type": "Recipe", "name": "Found Recipe"}
        ]
        """
        
        let document = try createDocumentWithJsonLd(jsonLd)
        let detector = JsonLdDetector()
        
        let result = detector.detect(in: document)
        
        XCTAssertNotNil(result, "Should find Recipe in array of objects")
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.name), "Found Recipe")
    }
    
    func testNonRecipeJsonLdIgnored() throws {
        // Test that non-recipe JSON-LD is ignored
        let jsonLd = """
        {
            "@type": "Organization",
            "name": "Test Organization"
        }
        """
        
        let document = try createDocumentWithJsonLd(jsonLd)
        let detector = JsonLdDetector()
        
        let result = detector.detect(in: document)
        
        XCTAssertNil(result, "Should return nil for non-recipe JSON-LD")
    }
    
    // MARK: - Field Extraction Tests
    
    func testExtractStringFromVariousFormats() {
        XCTAssertEqual(RecipeFieldExtractor.extractString("Test"), "Test")
        XCTAssertEqual(RecipeFieldExtractor.extractString(["First", "Second"]), "First")
        XCTAssertEqual(RecipeFieldExtractor.extractString(["name": "Named"]), "Named")
        XCTAssertEqual(RecipeFieldExtractor.extractString(["@value": "Value"]), "Value")
        XCTAssertEqual(RecipeFieldExtractor.extractString(["text": "Text"]), "Text")
        XCTAssertEqual(RecipeFieldExtractor.extractString(["@id": "some-id"]), "some-id")
        XCTAssertNil(RecipeFieldExtractor.extractString(nil))
        XCTAssertEqual(RecipeFieldExtractor.extractString("  trimmed  "), "trimmed")
    }
    
    func testExtractImageFromVariousFormats() {
        XCTAssertEqual(
            RecipeFieldExtractor.extractImage("https://example.com/image.jpg"),
            "https://example.com/image.jpg"
        )
        XCTAssertEqual(
            RecipeFieldExtractor.extractImage(["url": "https://example.com/img.jpg"]),
            "https://example.com/img.jpg"
        )
        XCTAssertEqual(
            RecipeFieldExtractor.extractImage(["contentUrl": "https://example.com/content.jpg"]),
            "https://example.com/content.jpg"
        )
        XCTAssertEqual(
            RecipeFieldExtractor.extractImage(["https://example.com/1.jpg", "https://example.com/2.jpg"]),
            "https://example.com/1.jpg"
        )
        XCTAssertEqual(
            RecipeFieldExtractor.extractImage([
                "@type": "ImageObject",
                "url": "https://example.com/imageobject.jpg",
                "width": 1200
            ]),
            "https://example.com/imageobject.jpg"
        )
        XCTAssertNil(RecipeFieldExtractor.extractImage(nil))
    }
    
    func testExtractIngredientsFromArray() {
        let ingredients = ["2 cups flour", "1 cup sugar", "2 eggs"]
        
        let result = RecipeFieldExtractor.extractIngredients(ingredients)
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "2 cups flour")
        XCTAssertEqual(result[1], "1 cup sugar")
        XCTAssertEqual(result[2], "2 eggs")
    }
    
    func testExtractIngredientsFromNewlineSeparatedString() {
        let ingredients = "2 cups flour\n1 cup sugar\n2 eggs"
        
        let result = RecipeFieldExtractor.extractIngredients(ingredients)
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "2 cups flour")
    }
    
    func testExtractInstructionsFromHowToStep() {
        let instructions: [[String: Any]] = [
            ["@type": "HowToStep", "text": "Step one"],
            ["@type": "HowToStep", "text": "Step two"],
            ["@type": "HowToStep", "name": "Step three"]
        ]
        
        let result = RecipeFieldExtractor.extractInstructions(instructions)
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "Step one")
        XCTAssertEqual(result[1], "Step two")
        XCTAssertEqual(result[2], "Step three")
    }
    
    func testExtractInstructionsFromHowToSection() {
        let instructions: [[String: Any]] = [
            [
                "@type": "HowToSection",
                "name": "Preparation",
                "itemListElement": [
                    ["@type": "HowToStep", "text": "Prep step 1"],
                    ["@type": "HowToStep", "text": "Prep step 2"]
                ]
            ],
            [
                "@type": "HowToSection",
                "name": "Cooking",
                "itemListElement": [
                    ["@type": "HowToStep", "text": "Cook step 1"]
                ]
            ]
        ]
        
        let result = RecipeFieldExtractor.extractInstructions(instructions)
        
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.contains("Prep step 1"))
        XCTAssertTrue(result.contains("Prep step 2"))
        XCTAssertTrue(result.contains("Cook step 1"))
    }
    
    func testExtractInstructionsFromStringArray() {
        let instructions = ["Mix ingredients", "Bake for 30 minutes", "Let cool"]
        
        let result = RecipeFieldExtractor.extractInstructions(instructions)
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "Mix ingredients")
    }
    
    func testExtractInstructionsFromNewlineSeparatedString() {
        let instructions = "Mix ingredients\nBake for 30 minutes\nLet cool"
        
        let result = RecipeFieldExtractor.extractInstructions(instructions)
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "Mix ingredients")
    }
    
    func testExtractKeywordsFromArray() {
        let keywords = ["dessert", "baking", "cookies"]
        
        let result = RecipeFieldExtractor.extractKeywords(keywords)
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "dessert")
    }
    
    func testExtractKeywordsFromCommaSeparatedString() {
        let keywords = "dessert, baking, cookies"
        
        let result = RecipeFieldExtractor.extractKeywords(keywords)
        
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "dessert")
        XCTAssertEqual(result[1], "baking")
        XCTAssertEqual(result[2], "cookies")
    }
    
    func testExtractAuthorFromString() {
        let result = RecipeFieldExtractor.extractAuthor("John Doe")
        XCTAssertEqual(result, "John Doe")
    }
    
    func testExtractAuthorFromObject() {
        let author: [String: Any] = ["@type": "Person", "name": "Jane Smith"]
        
        let result = RecipeFieldExtractor.extractAuthor(author)
        
        XCTAssertEqual(result, "Jane Smith")
    }
    
    func testExtractAuthorFromArray() {
        let authors: [Any] = [
            ["name": "First Author"],
            ["name": "Second Author"]
        ]
        
        let result = RecipeFieldExtractor.extractAuthor(authors)
        
        XCTAssertEqual(result, "First Author")
    }
    
    func testExtractYieldFromInteger() {
        let (numeric, text) = RecipeFieldExtractor.extractYield(4)
        
        XCTAssertEqual(numeric, 4)
        XCTAssertNil(text)
    }
    
    func testExtractYieldFromStringWithNumber() {
        let (numeric, text) = RecipeFieldExtractor.extractYield("4 servings")
        
        XCTAssertEqual(numeric, 4)
        XCTAssertEqual(text, "4 servings")
    }
    
    func testExtractYieldFromNumericString() {
        let (numeric, text) = RecipeFieldExtractor.extractYield("12")
        
        XCTAssertEqual(numeric, 12)
        XCTAssertEqual(text, "12")
    }
    
    func testExtractYieldFromComplexText() {
        let (numeric, text) = RecipeFieldExtractor.extractYield("Makes 24 cookies")
        
        XCTAssertEqual(numeric, 24)
        XCTAssertEqual(text, "Makes 24 cookies")
    }
    
    func testExtractYieldFromNil() {
        let (numeric, text) = RecipeFieldExtractor.extractYield(nil)
        
        XCTAssertEqual(numeric, 0)
        XCTAssertNil(text)
    }
    
    func testExtractNutrition() {
        let nutrition: [String: Any] = [
            "@type": "NutritionInformation",
            "calories": "250 calories",
            "fatContent": "10g",
            "proteinContent": "5g"
        ]
        
        let result = RecipeFieldExtractor.extractNutrition(nutrition)
        
        XCTAssertEqual(result["calories"], "250 calories")
        XCTAssertEqual(result["fatContent"], "10g")
        XCTAssertEqual(result["proteinContent"], "5g")
    }
    
    // MARK: - HTML Utility Tests
    
    func testDecodeHtmlNamedEntities() {
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&amp;"), "&")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&lt;"), "<")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&gt;"), ">")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&quot;"), "\"")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&nbsp;"), " ")
    }
    
    func testDecodeHtmlFractionEntities() {
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&frac12;"), "½")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&frac14;"), "¼")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&frac34;"), "¾")
    }
    
    func testDecodeHtmlDegreeEntity() {
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&deg;"), "°")
    }
    
    func testDecodeHtmlCombinedEntities() {
        XCTAssertEqual(
            HtmlUtilities.decodeHtmlEntities("1&frac12; cups &amp; 2 tbsp"),
            "1½ cups & 2 tbsp"
        )
    }
    
    func testDecodeHtmlPunctuationEntities() {
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&mdash;"), "—")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&ndash;"), "–")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&hellip;"), "…")
    }
    
    func testDecodeHtmlQuoteEntities() {
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&lsquo;"), "'")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&rsquo;"), "'")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&ldquo;"), "\"")
        XCTAssertEqual(HtmlUtilities.decodeHtmlEntities("&rdquo;"), "\"")
    }
    
    func testStripHtmlTags() {
        XCTAssertEqual(
            HtmlUtilities.stripHtmlTags("<p>Hello <strong>world</strong></p>"),
            "Hello world"
        )
        XCTAssertEqual(
            HtmlUtilities.stripHtmlTags("Plain text"),
            "Plain text"
        )
        XCTAssertEqual(
            HtmlUtilities.stripHtmlTags("<br>Line<br/>break"),
            "Linebreak"
        )
        XCTAssertEqual(
            HtmlUtilities.stripHtmlTags("<div class=\"test\">Content</div>"),
            "Content"
        )
    }
    
    func testCleanIngredient() {
        XCTAssertEqual(
            HtmlUtilities.cleanIngredient("<span>1 &frac12; cups flour</span>"),
            "1 ½ cups flour"
        )
        XCTAssertEqual(
            HtmlUtilities.cleanIngredient("  2 eggs  "),
            "2 eggs"
        )
    }
    
    func testCleanInstructionRemovesStepNumbers() {
        XCTAssertEqual(HtmlUtilities.cleanInstruction("1. Mix flour"), "Mix flour")
        XCTAssertEqual(HtmlUtilities.cleanInstruction("Step 1: Mix flour"), "Mix flour")
        XCTAssertEqual(HtmlUtilities.cleanInstruction("(1) Mix flour"), "Mix flour")
        XCTAssertEqual(HtmlUtilities.cleanInstruction("• Mix flour"), "Mix flour")
    }
    
    func testCleanInstructionRemovesHtmlAndDecodesEntities() {
        XCTAssertEqual(HtmlUtilities.cleanInstruction("<p>Mix flour</p>"), "Mix flour")
        XCTAssertEqual(HtmlUtilities.cleanInstruction("Add &frac12; cup"), "Add ½ cup")
        XCTAssertEqual(
            HtmlUtilities.cleanInstruction("<li>1. Add &amp; mix</li>"),
            "Add & mix"
        )
    }
    
    func testSanitizeJsonString() {
        let newlineInput = "Line1\nLine2"
        let newlineResult = HtmlUtilities.sanitizeJsonString(newlineInput)
        XCTAssertTrue(newlineResult.contains("\\n"))
        
        let tabInput = "Tab\there"
        let tabResult = HtmlUtilities.sanitizeJsonString(tabInput)
        XCTAssertTrue(tabResult.contains("\\t"))
    }
    
    // MARK: - Integration Tests
    
    func testFullJsonLdDetectionFlow() throws {
        let html = """
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Test Recipe",
                "description": "A test recipe for unit testing",
                "recipeIngredient": ["Ingredient 1", "Ingredient 2"],
                "recipeInstructions": [
                    {"@type": "HowToStep", "text": "Step 1"},
                    {"@type": "HowToStep", "text": "Step 2"}
                ],
                "prepTime": "PT30M",
                "cookTime": "PT1H",
                "recipeYield": "4 servings",
                "author": {"@type": "Person", "name": "Test Chef"}
            }
            </script>
        </head>
        <body></body>
        </html>
        """
        
        let document = try SwiftSoup.parse(html)
        let detector = JsonLdDetector()
        
        let result = detector.detect(in: document)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.name), "Test Recipe")
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.description), "A test recipe for unit testing")
        
        let ingredients = RecipeFieldExtractor.extractIngredients(result?.recipeIngredient)
        XCTAssertEqual(ingredients.count, 2)
        XCTAssertEqual(ingredients[0], "Ingredient 1")
        
        let instructions = RecipeFieldExtractor.extractInstructions(result?.recipeInstructions)
        XCTAssertEqual(instructions.count, 2)
        XCTAssertEqual(instructions[0], "Step 1")
        
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.prepTime), "PT30M")
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.cookTime), "PT1H")
        
        let (yieldNum, yieldText) = RecipeFieldExtractor.extractYield(result?.recipeYield)
        XCTAssertEqual(yieldNum, 4)
        XCTAssertEqual(yieldText, "4 servings")
        
        XCTAssertEqual(RecipeFieldExtractor.extractAuthor(result?.author), "Test Chef")
    }
    
    func testMultipleJsonLdScriptsSelectsRecipe() throws {
        let html = """
        <html>
        <head>
            <script type="application/ld+json">
            {"@type": "Organization", "name": "My Website"}
            </script>
            <script type="application/ld+json">
            {"@type": "Recipe", "name": "The Recipe"}
            </script>
            <script type="application/ld+json">
            {"@type": "BreadcrumbList", "itemListElement": []}
            </script>
        </head>
        <body></body>
        </html>
        """
        
        let document = try SwiftSoup.parse(html)
        let detector = JsonLdDetector()
        
        let result = detector.detect(in: document)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(RecipeFieldExtractor.extractString(result?.name), "The Recipe")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyIngredients() {
        let result = RecipeFieldExtractor.extractIngredients(nil)
        XCTAssertTrue(result.isEmpty)
        
        let emptyArray = RecipeFieldExtractor.extractIngredients([String]())
        XCTAssertTrue(emptyArray.isEmpty)
    }
    
    func testEmptyInstructions() {
        let result = RecipeFieldExtractor.extractInstructions(nil)
        XCTAssertTrue(result.isEmpty)
        
        let emptyArray = RecipeFieldExtractor.extractInstructions([String]())
        XCTAssertTrue(emptyArray.isEmpty)
    }
    
    func testWhitespaceOnlyStrings() {
        XCTAssertEqual(RecipeFieldExtractor.extractString("   "), "")
        XCTAssertEqual(RecipeFieldExtractor.extractString("\n\t"), "")
    }
}

// MARK: - Test Helpers

extension RecipeImportTests {
    /// Create a SwiftSoup Document with embedded JSON-LD
    func createDocumentWithJsonLd(_ jsonLd: String) throws -> Document {
        let html = """
        <html>
        <head>
            <script type="application/ld+json">\(jsonLd)</script>
        </head>
        <body></body>
        </html>
        """
        return try SwiftSoup.parse(html)
    }
}
