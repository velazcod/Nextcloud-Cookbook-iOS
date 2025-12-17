//
//  Nextcloud_Cookbook_iOS_ClientTests.swift
//  Nextcloud Cookbook iOS ClientTests
//
//  Created by Vincent Meilinger on 06.09.23.
//

import XCTest
@testable import Nextcloud_Cookbook_iOS_Client

final class Nextcloud_Cookbook_iOS_ClientTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testExtractImageFromImageObject() throws {
        // Test extracting image URL from schema.org ImageObject format
        let imageObject: [String: Any] = [
            "@type": "ImageObject",
            "url": "https://www.allrecipes.com/thmb/...",
            "height": 960,
            "width": 960
        ]

        let extractedUrl = RecipeFieldExtractor.extractImage(imageObject)
        XCTAssertEqual(extractedUrl, "https://www.allrecipes.com/thmb/...", "Should extract URL from ImageObject")
    }

    func testExtractImageFromString() throws {
        // Test extracting image URL from plain string
        let imageUrl = "https://example.com/image.jpg"
        let extractedUrl = RecipeFieldExtractor.extractImage(imageUrl)
        XCTAssertEqual(extractedUrl, imageUrl, "Should return string URL as-is")
    }

    func testExtractImageFromArray() throws {
        // Test extracting image URL from array of images
        let imageArray: [Any] = [
            [
                "@type": "ImageObject",
                "url": "https://www.example.com/image1.jpg"
            ],
            "https://www.example.com/image2.jpg"
        ]

        let extractedUrl = RecipeFieldExtractor.extractImage(imageArray)
        XCTAssertEqual(extractedUrl, "https://www.example.com/image1.jpg", "Should extract URL from first ImageObject in array")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
