//
//  RecipeTestHelpers.swift
//  Nextcloud Cookbook iOS ClientTests
//

import Foundation
import SwiftSoup
@testable import Nextcloud_Cookbook_iOS_Client

func createDocument(from html: String) throws -> Document {
    return try SwiftSoup.parse(html)
}

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

func createDocumentWithNextData(_ json: String) throws -> Document {
    let html = """
    <html>
    <head></head>
    <body>
        <script id="__NEXT_DATA__" type="application/json">\(json)</script>
    </body>
    </html>
    """
    return try SwiftSoup.parse(html)
}

func createDocumentWithMicrodata(
    name: String,
    ingredients: [String] = [],
    instructions: [String] = []
) throws -> Document {
    let ingredientHtml = ingredients.map {
        "<li itemprop=\"recipeIngredient\">\($0)</li>"
    }.joined()
    
    let instructionHtml = instructions.map {
        "<li itemtype=\"https://schema.org/HowToStep\" itemprop=\"recipeInstructions\"><span itemprop=\"text\">\($0)</span></li>"
    }.joined()
    
    let html = """
    <html>
    <body>
        <div itemscope itemtype="https://schema.org/Recipe">
            <h1 itemprop="name">\(name)</h1>
            <ul>\(ingredientHtml)</ul>
            <ol>\(instructionHtml)</ol>
        </div>
    </body>
    </html>
    """
    return try SwiftSoup.parse(html)
}
