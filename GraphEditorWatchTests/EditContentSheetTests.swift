//
//  EditContentSheetTests.swift
//  GraphEditor
//
//  Created by handcart on 9/25/25.
//
import Testing
import SwiftUI
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct EditContentSheetTests {
    private func setupViewModel() async -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = await GraphModel(storage: storage, physicsEngine: physicsEngine)
        return await GraphViewModel(model: model)
    }
    
    // MARK: - NodeContent Tests
    
    @Test("NodeContent string display truncation")
    func testStringDisplayTruncation() {
        let shortString = NodeContent.string("Hello")
        #expect(shortString.displayText == "Hello", "Short strings should not be truncated")
        
        let longString = NodeContent.string("This is a very long string that should be truncated")
        #expect(longString.displayText == "This is a very long string that should be truncated", "displayText returns full string without truncation")
        
        let exactlyTen = NodeContent.string("1234567890")
        #expect(exactlyTen.displayText == "1234567890", "Exactly 10 chars should not be truncated")
    }
    
    @Test("NodeContent date formatting")
    func testDateFormatting() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2025, month: 12, day: 25)
        guard let testDate = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }
        
        let dateContent = NodeContent.date(testDate)
        let displayText = dateContent.displayText
        
        // Should format as short date (format varies by locale, but should contain year/month/day)
        #expect(displayText.contains("25") || displayText.contains("12") || displayText.contains("2025"),
                "Date display should contain date components")
    }
    
    @Test("NodeContent number formatting")
    func testNumberFormatting() {
        let wholeNumber = NodeContent.number(42.0)
        #expect(wholeNumber.displayText == "42.00", "Whole numbers should show 2 decimal places")
        
        let decimal = NodeContent.number(3.14159)
        #expect(decimal.displayText == "3.14", "Decimals should be formatted to 2 places")
        
        let negative = NodeContent.number(-99.999)
        #expect(negative.displayText == "-100.00", "Negative numbers should format correctly")
    }
    
    @Test("NodeContent boolean formatting")
    func testBooleanFormatting() {
        let trueValue = NodeContent.boolean(true)
        #expect(trueValue.displayText == "True", "Boolean true should display as 'True'")
        
        let falseValue = NodeContent.boolean(false)
        #expect(falseValue.displayText == "False", "Boolean false should display as 'False'")
    }
    
    @Test("NodeContent equality")
    func testContentEquality() {
        let string1 = NodeContent.string("test")
        let string2 = NodeContent.string("test")
        let string3 = NodeContent.string("different")
        
        #expect(string1 == string2, "Same strings should be equal")
        #expect(string1 != string3, "Different strings should not be equal")
        
        let num1 = NodeContent.number(42.0)
        let num2 = NodeContent.number(42.0)
        #expect(num1 == num2, "Same numbers should be equal")
        
        // Different types should not be equal
        #expect(NodeContent.string("42") != NodeContent.number(42.0), "Different types should not be equal")
    }
    
    @Test("NodeContent codable round-trip")
    func testCodableRoundTrip() throws {
        let contents: [NodeContent] = [
            .string("Hello World"),
            .date(Date(timeIntervalSince1970: 1640000000)),
            .number(123.45),
            .boolean(true)
        ]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for content in contents {
            let encoded = try encoder.encode(content)
            let decoded = try decoder.decode(NodeContent.self, from: encoded)
            #expect(content == decoded, "Content should survive encode/decode cycle: \(content)")
        }
    }
    
    // MARK: - Node with Content Tests
    
    @MainActor @Test("Node stores multiple contents")
    func testNodeMultipleContents() async {
        let viewModel = await setupViewModel()
        let contents: [NodeContent] = [
            .string("Title"),
            .date(Date()),
            .number(100.0)
        ]
        
        let node = await viewModel.model.addNode(at: .zero)
        await viewModel.model.updateNodeContents(withID: node.id, newContents: contents)
        
        let updatedNode = viewModel.model.nodes.first { $0.id == node.id }
        #expect(updatedNode?.contents.count == 3, "Node should store all three content items")
        #expect(updatedNode?.contents[0] == .string("Title"), "First content should match")
    }
    
    @MainActor @Test("Empty contents array by default")
    func testNodeEmptyContentsByDefault() async {
        let viewModel = await setupViewModel()
        let node = await viewModel.model.addNode(at: .zero)
        
        #expect(node.contents.isEmpty, "New nodes should have empty contents array")
    }
    
    @MainActor @Test("Content persists through save/load")
    func testContentPersistence() async {
        let viewModel = await setupViewModel()
        let testContents: [NodeContent] = [
            .string("Persistent"),
            .number(42.0)
        ]
        
        let node = await viewModel.model.addNode(at: CGPoint(x: 10, y: 20))
        await viewModel.model.updateNodeContents(withID: node.id, newContents: testContents)
        
        // Save
        try? await viewModel.model.saveGraph()
        
        // Create new model with same storage
        let storage = viewModel.model.storage
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let newModel = GraphModel(storage: storage, physicsEngine: physicsEngine)
        try? await newModel.loadGraph()
        
        let loadedNode = newModel.nodes.first { $0.id == node.id }
        #expect(loadedNode?.contents == testContents, "Content should persist through save/load")
    }
    
    @MainActor @Test("Content displayed in accessibility label")
    func testContentInAccessibilityLabel() async {
        let viewModel = await setupViewModel()
        let node = await viewModel.model.addNode(at: .zero)
        await viewModel.model.updateNodeContents(withID: node.id, newContents: [.string("Important")])
        
        let updatedNode = viewModel.model.nodes.first { $0.id == node.id }
        #expect(updatedNode != nil, "Node should exist")
        
        // The accessibility label is built in NodeView, so we verify the content is accessible
        #expect(!updatedNode!.contents.isEmpty, "Content should be available for accessibility")
        #expect(updatedNode!.contents[0].displayText == "Important", "Content text should be accessible")
    }
}
