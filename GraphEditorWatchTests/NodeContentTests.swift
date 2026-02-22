//
//  NodeContentTests.swift
//  GraphEditorWatchTests
//
//  Tests for NodeContent display behavior
//

import Testing
import Foundation
@testable import GraphEditorShared

struct NodeContentTests {
    
    // MARK: - String Content Display
    
    @Test("String content displays full text without truncation")
    func testStringContentNoTruncation() {
        let shortString = NodeContent.string("Hello")
        let mediumString = NodeContent.string("Daniel Higgins")  // 14 characters
        let longString = NodeContent.string("This is a very long name that exceeds typical limits")
        
        #expect(shortString.displayText == "Hello", "Short strings should display fully")
        #expect(mediumString.displayText == "Daniel Higgins", "Medium strings should display fully")
        #expect(longString.displayText == "This is a very long name that exceeds typical limits", 
                "Long strings should display fully without truncation")
    }
    
    @Test("Empty string content displays correctly")
    func testEmptyStringContent() {
        let emptyString = NodeContent.string("")
        #expect(emptyString.displayText == "", "Empty string should remain empty")
    }
    
    @Test("String content preserves special characters")
    func testStringContentSpecialCharacters() {
        let specialChars = NodeContent.string("Name with émojis 🎉 and spéciål çhars")
        #expect(specialChars.displayText == "Name with émojis 🎉 and spéciål çhars",
                "Special characters and emojis should be preserved")
    }
    
    // MARK: - Date Content Display
    
    @Test("Date content formats to short date style")
    func testDateContentFormatting() {
        let date = Date(timeIntervalSince1970: 0)  // Jan 1, 1970
        let dateContent = NodeContent.date(date)
        
        // The exact format varies by locale, but should contain date components
        let displayText = dateContent.displayText
        #expect(displayText.count > 0, "Date should format to non-empty string")
        #expect(displayText.contains("/") || displayText.contains("-"), 
                "Date should contain typical separators")
    }
    
    // MARK: - Number Content Display
    
    @Test("Number content formats to 2 decimal places")
    func testNumberContentFormatting() {
        let integer = NodeContent.number(42.0)
        let decimal = NodeContent.number(3.14159)
        let negative = NodeContent.number(-123.456)
        
        #expect(integer.displayText == "42.00", "Integer should format with 2 decimals")
        #expect(decimal.displayText == "3.14", "Decimal should round to 2 places")
        #expect(negative.displayText == "-123.46", "Negative should format correctly")
    }
    
    // MARK: - Boolean Content Display
    
    @Test("Boolean content displays as True or False")
    func testBooleanContentDisplay() {
        let trueContent = NodeContent.boolean(true)
        let falseContent = NodeContent.boolean(false)
        
        #expect(trueContent.displayText == "True", "True should display as 'True'")
        #expect(falseContent.displayText == "False", "False should display as 'False'")
    }
    
    // MARK: - PersonNode Content Integration
    
    @Test("PersonNode name displays fully in contents")
    @available(iOS 16.0, watchOS 9.0, *)
    func testPersonNodeNameDisplay() {
        let person = PersonNode(
            label: 1,
            position: .zero,
            name: "Daniel Higgins"
        )
        
        let contents = person.contents
        #expect(contents.count > 0, "PersonNode should have contents")
        
        if let firstContent = contents.first {
            #expect(firstContent.displayText == "Daniel Higgins",
                    "Person name should display fully without truncation")
        }
    }
    
    @Test("PersonNode with long name displays fully")
    @available(iOS 16.0, watchOS 9.0, *)
    func testPersonNodeLongNameDisplay() {
        let person = PersonNode(
            label: 1,
            position: .zero,
            name: "Christopher Montgomery-Wellington III"
        )
        
        let contents = person.contents
        if let firstContent = contents.first {
            #expect(firstContent.displayText == "Christopher Montgomery-Wellington III",
                    "Long person names should display fully")
        }
    }
    
    @Test("PersonNode with dietary restrictions shows all content")
    @available(iOS 16.0, watchOS 9.0, *)
    func testPersonNodeWithRestrictions() {
        let person = PersonNode(
            label: 1,
            position: .zero,
            name: "Jane Smith",
            defaultSpiceLevel: "hot",
            dietaryRestrictions: ["vegetarian", "gluten-free"]
        )
        
        let contents = person.contents
        #expect(contents.count == 3, "Should have name, spice level, and restrictions")
        
        // First content should be the name
        #expect(contents[0].displayText == "Jane Smith", "Name should be first")
        
        // Second should be spice level
        #expect(contents[1].displayText == "Spice: hot", "Spice level should be second")
        
        // Third should be dietary restrictions
        #expect(contents[2].displayText == "vegetarian, gluten-free", 
                "Restrictions should be comma-separated")
    }
}
